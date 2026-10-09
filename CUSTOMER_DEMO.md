# VakilSetu customer demo

This source is configured so debug and profile builds automatically open the
complete customer demo. No `DEMO_MODE` argument is required.

## Android APK

```sh
flutter clean
flutter pub get
flutter build apk --debug
```

Install `build/app/outputs/flutter-apk/app-debug.apk` after uninstalling any
older copy signed by a different debug certificate.

## Web preview

```sh
flutter pub get
flutter run -d chrome
```

Release builds remain fail-closed until production authentication and E2EE are
connected. For a presentation-only web release, explicitly use
`--dart-define=DEMO_MODE=true`.
