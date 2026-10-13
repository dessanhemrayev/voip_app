import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;

  RegisterWidget(this._helper, {Key? key}) : super(key: key);

  @override
  State<RegisterWidget> createState() => _MyRegisterWidget();
}

class _MyRegisterWidget extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _wsUriController = TextEditingController();
  final TextEditingController _sipUriController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _authorizationUserController =
      TextEditingController();
  final TextEditingController _stunUriController = TextEditingController();
  final TextEditingController _turnUriController = TextEditingController();
  final TextEditingController _turnUsernameController = TextEditingController();
  final TextEditingController _turnPasswordController = TextEditingController();
  final Map<String, String> _wsExtraHeaders = {
    'Origin': ' https://hostname',
    'Host': 'hostname'
  };
  late SharedPreferences _preferences;
  late final Future<void> _settingsLoaded;
  late RegistrationState _registerState;

  TransportType _selectedTransport = TransportType.TCP;

  SIPUAHelper? get helper => widget._helper;

  @override
  void initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _settingsLoaded = _loadSettings();
    if (kIsWeb) {
      _selectedTransport = TransportType.WS;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _portController.dispose();
    _wsUriController.dispose();
    _sipUriController.dispose();
    _displayNameController.dispose();
    _authorizationUserController.dispose();
    _stunUriController.dispose();
    _turnUriController.dispose();
    _turnUsernameController.dispose();
    _turnPasswordController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _saveSettings();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _portController.text = '8089';
      _wsUriController.text =
          _preferences.getString('ws_uri') ?? 'wss://hostname:8089/ws';
      _sipUriController.text =
          _preferences.getString('sip_uri') ?? '101@hostname';
      _displayNameController.text =
          _preferences.getString('display_name') ?? '101';
      _passwordController.text = _preferences.getString('password') ?? '';
      _authorizationUserController.text =
          _preferences.getString('auth_user') ?? '101';
      final String? iceJson = _preferences.getString('ice_config');
      if (iceJson != null) {
        try {
          final Map<String, dynamic> ice =
              jsonDecode(iceJson) as Map<String, dynamic>;
          _stunUriController.text = ice['stun'] as String? ?? '';
          _turnUriController.text = ice['turn'] as String? ?? '';
          _turnUsernameController.text = ice['turn_user'] as String? ?? '';
          _turnPasswordController.text = ice['turn_pass'] as String? ?? '';
        } catch (_) {}
      }
    });
  }

  Future<void> _saveSettings() async {
    _preferences = await SharedPreferences.getInstance();
    await _preferences.setString('port', _portController.text);
    await _preferences.setString('ws_uri', _wsUriController.text);
    await _preferences.setString('sip_uri', _sipUriController.text);
    await _preferences.setString('display_name', _displayNameController.text);
    await _preferences.setString('password', _passwordController.text);
    await _preferences.setString('auth_user', _authorizationUserController.text);
    // Single value so the ICE fields can never be partially persisted.
    await _preferences.setString(
        'ice_config',
        jsonEncode(<String, String>{
          'stun': _stunUriController.text,
          'turn': _turnUriController.text,
          'turn_user': _turnUsernameController.text,
          'turn_pass': _turnPasswordController.text,
        }));
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      _registerState = state;
    });
  }

  void _alert(BuildContext context, String alertFieldName) {
    _alertMessage(context, '$alertFieldName is empty',
        'Please enter $alertFieldName!');
  }

  void _alertMessage(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    await _settingsLoaded;
    if (!context.mounted) return;
    if (_wsUriController.text == '') {
      _alert(context, "WebSocket URL");
    } else if (_sipUriController.text == '') {
      _alert(context, "SIP URI");
    }

    final String turnUser = _turnUsernameController.text.trim();
    final String turnPass = _turnPasswordController.text.trim();
    if (_turnUriController.text.trim().isNotEmpty &&
        turnUser.isNotEmpty != turnPass.isNotEmpty) {
      _alertMessage(context, 'Incomplete TURN credentials',
          'Enter both TURN username and password, or leave both empty.');
      return;
    }

    UaSettings settings = UaSettings();

    settings.port = _portController.text;
    settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
    settings.tcpSocketSettings.allowBadCertificate = true;
    settings.transportType = _selectedTransport;
    settings.uri = _sipUriController.text;
    settings.webSocketUrl = _wsUriController.text;
    settings.host = _sipUriController.text.split('@')[1];
    settings.authorizationUser = _authorizationUserController.text;
    settings.password = _passwordController.text;
    settings.displayName = _displayNameController.text;
    settings.userAgent = 'Dart SIP Client v1.0.0';
    settings.dtmfMode = DtmfMode.RFC2833;
    settings.contact_uri = 'sip:${_sipUriController.text}';

    // Build ICE servers (STUN/TURN)
    List<Map<String, String>> iceServers = <Map<String, String>>[];
    final String stun = _stunUriController.text.trim();
    if (stun.isNotEmpty) {
      iceServers.add(<String, String>{'urls': stun});
    }
    final String turn = _turnUriController.text.trim();
    if (turn.isNotEmpty) {
      if (turnUser.isNotEmpty && turnPass.isNotEmpty) {
        iceServers.add(<String, String>{
          'urls': turn,
          'username': turnUser,
          'credential': turnPass,
        });
      } else {
        iceServers.add(<String, String>{'urls': turn});
      }
    }
    if (iceServers.isEmpty) {
      iceServers = <Map<String, String>>[
        <String, String>{'urls': 'stun:stun.l.google.com:19302'},
      ];
    }
    settings.iceServers = iceServers;

    await _saveSettings();
    helper!.start(settings);
  }

  @override
  Widget build(BuildContext context) {
    Color? textColor = Theme.of(context).textTheme.bodyMedium?.color;
    Color? textFieldFill =
        Theme.of(context).buttonTheme.colorScheme?.surfaceContainerLowest;
    OutlineInputBorder border = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(5),
    );
    Color? textLabelColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5);
    return Scaffold(
      appBar: AppBar(
        title: Text("SIP Account"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        children: <Widget>[
          Center(
            child: Text(
              'Register Status: ${_registerState.state.toString().split('.').last}',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
          ),
          SizedBox(height: 15),
          if (_selectedTransport == TransportType.WS) ...[
            Text('WebSocket', style: TextStyle(color: textLabelColor)),
            SizedBox(height: 5),
            TextFormField(
              controller: _wsUriController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textAlign: TextAlign.center,
            ),
          ],
          if (_selectedTransport == TransportType.TCP) ...[
            Text('Port', style: TextStyle(color: textLabelColor)),
            SizedBox(height: 5),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.text,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: textFieldFill,
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ],
          SizedBox(height: 15),
          Text('SIP URI', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _sipUriController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
          SizedBox(height: 15),
          Text('Authorization User', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _authorizationUserController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText:
                  _authorizationUserController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 15),
          Text('Password', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _passwordController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: _passwordController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 15),
          Text('Display Name', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _displayNameController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: _displayNameController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 15),
          Text('STUN Server (optional)', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _stunUriController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: 'stun:host:3478',
            ),
          ),
          SizedBox(height: 15),
          Text('TURN Server (optional)', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _turnUriController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: 'turn:host:3478',
            ),
          ),
          SizedBox(height: 15),
          Text('TURN Username', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _turnUsernameController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: '[Empty]',
            ),
          ),
          SizedBox(height: 15),
          Text('TURN Password', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _turnPasswordController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            obscureText: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: '[Empty]',
            ),
          ),
          const SizedBox(height: 20),
          if (!kIsWeb) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RadioMenuButton<TransportType>(
                    value: TransportType.TCP,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("TCP")),
                RadioMenuButton<TransportType>(
                    value: TransportType.WS,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("WS")),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            child: Text('Register'),
            onPressed: () => _handleSave(context),
          ),
        ],
      ),
    );
  }

  @override
  void callStateChanged(Call call, CallState state) {
    //NO OP
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }

  @override
  void onNewReinvite(ReInvite event) {
    // TODO: implement onNewReinvite
  }
}
