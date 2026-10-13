# VoIP App

A Flutter softphone for making and receiving SIP audio and video calls. SIP signaling is provided by [sip_ua](https://github.com/flutter-webrtc/dart-sip-ua), and call media uses WebRTC.

## Features

- Register a SIP account over TCP or WebSocket (WebSocket is selected on web).
- Place and receive audio or video calls.
- During a call, mute audio or video, switch cameras, use speakerphone, put the call on hold, transfer it, and send DTMF tones.
- Save SIP account settings and the last destination locally between launches.
- Switch between light and dark themes.

## Requirements

- Flutter SDK with Dart 3.5.2 or later.
- A SIP account and a SIP server configured for the selected transport and WebRTC media.
- A device or browser with microphone access; video calls also need camera access. On mobile, the app requests microphone and camera permissions when starting a call. In the web version, starting a video call opens browser screen sharing.

## Run

```sh
flutter pub get
flutter run
```

To run in Chrome, use `flutter run -d chrome`. Select a target device in your IDE or pass its device ID with `-d`.

## Configure a SIP account

Open the app menu, choose **Account**, enter your provider's settings, then select **Register**:

- **SIP URI**: SIP identity in `user@domain` form, for example `101@sip.example.com`.
- **Authorization User**: authentication username, if different from the SIP URI user.
- **Password**: SIP account password.
- **Display Name**: optional name shown to other call participants.
- **Transport**: TCP or WS. For TCP, enter the server port. For WS, enter the WebSocket URL, for example `wss://sip.example.com:8089/ws`.

After registration, enter a phone number or SIP URI in **Destination URL**. Use the video button for a video call or the phone button for an audio-only call. Incoming calls can be accepted or rejected from the call screen.

Account settings, including the SIP password, are saved in local `SharedPreferences`. They are not encrypted by this app; avoid saving credentials on untrusted devices.


## Android releases

The `Release` GitHub Actions workflow runs on every push to `main`, except commits whose message contains `[skip ci]`. It builds a signed release APK, updates the version in `pubspec.yaml`, pushes a version tag, and publishes the APK as a GitHub Release.

### Configure Android signing

Create a release keystore locally and keep it in a secure backup. Do not commit the keystore or its passwords.

```sh
keytool -genkeypair -v \
	-keystore upload-keystore.jks \
	-keyalg RSA -keysize 2048 -validity 10000 \
	-alias upload
```

In the GitHub repository, open **Settings > Secrets and variables > Actions** and add these repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded contents of `upload-keystore.jks`; on Linux, run `base64 -w 0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias, for example `upload` |
| `ANDROID_KEY_PASSWORD` | Key password; optional when it matches the keystore password |

Keep using the same keystore for every release. Android will reject app updates signed with a different key. The workflow needs permission to push commits and tags to `main`; adjust branch protection rules if they block GitHub Actions pushes.

### Versioning

The workflow uses commit messages to choose the next version:

- `feat:` increments the minor version.
- A breaking change (`type!:` or `BREAKING CHANGE` in the commit body) increments the major version.
- Other commits increment the patch version.
- The build number after `+` increments on every release.

For example, a release may update `1.0.0+1` to `1.1.0+2`. The generated APK and release tag use the version name, such as `voip_app-v1.1.0.apk` and `v1.1.0`.

## Configure STUN/TURN (WebRTC NAT traversal)

By default the app uses Google's STUN server: stun:stun.l.google.com:19302. To improve connectivity behind NATs or symmetric firewalls you can add STUN and/or TURN servers in **Account > Register**:

- **STUN URI** (optional) — e.g. stun:stun.your.provider:3478
- **TURN URI** (optional) — e.g. turn:turn.your.provider:3478
- **TURN Username** (optional)
- **TURN Password/Credential** (optional)

If only STUN is provided, ICE will try direct and STUN-assisted paths. If TURN is provided, TURN relays are used when direct/STUN fails. These values are saved locally in SharedPreferences (not encrypted). If all fields are empty, the default STUN is used.

Example public STUN: stun:stun.l.google.com:19302, stun:stun1.l.google.com:19302.