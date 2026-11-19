# DFW Communication Mobile

Native Flutter Android client for the DFW Communication platform. The app connects to the production API and provides secure authentication, workspace metrics, WhatsApp conversations, SMS inboxes, phone configuration and call history.

## Requirements

- Flutter 3.50 or newer
- Dart 3.14 or newer
- Android SDK 37
- Android NDK 28.2.13676358
- Java 17

## Run locally

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://wtp.famenetworks.net/
```

The production URL is the default. Use `API_BASE_URL` to target another compatible environment. User credentials and server secrets must never be committed to this repository.

## Quality checks

```bash
flutter analyze
flutter test
flutter build apk --release
```

The release APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

## Android identity

- Application ID: `com.dfw.communication`
- Minimum Android API: 23
- Compile Android API: 37

## Current backend dependency

Foreground API and SSE communication use the existing DFW backend. Killed-app push notifications and background incoming-call delivery require Firebase configuration plus backend device-token and push-call endpoints; those values are intentionally not stored in the mobile repository.
