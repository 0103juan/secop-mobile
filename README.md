# secop-mobile

[![CI](https://github.com/0103juan/secop-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/0103juan/secop-mobile/actions/workflows/ci.yml)

**Contratos a la vista** on a phone: search a Colombian state entity and see what it contracted in a year, its top suppliers, the modalities, and the contracts themselves. A Flutter client of [secop-api](../secop-api), for Android and the web. The interface is in Spanish; this README is in English.

## What it does

- Search the 5,800 entities as you type (the request waits for a pause in typing).
- Open an entity on its latest year with contracts; switch year with chips.
- Indicators, ranked suppliers and modalities, then the contracts, loaded page by page.
- Tapping a modality lists only that modality's contracts; a chip shows the filter and removes it.
- Tapping a contract opens its file on SECOP in the browser.
- The same safeguard as the web dashboard: when one contract explains half or more of the year's total, a card says so and shows the total without it, because values are typed by hand at the source.
- On the web, every entity has its own URL (`#/entidad/890905211`).

## How it is built

- Four files: `lib/api.dart` (models and HTTP client), `lib/format.dart` (Colombian peso formatting), `lib/theme.dart` (the visual identity), `lib/main.dart` (two screens).
- Plain `StatefulWidget` state and `FutureBuilder`; two packages, `http` and `url_launcher`.
- The HTTP client is injected, so the widget test runs the whole journey against a fake API: search, open, page through contracts, switch to the year with the mistyped contract and read the warning.
- One dark Material 3 theme in `lib/theme.dart`, shared with the web dashboard. The two fonts in `fonts/` are bundled under the SIL Open Font License; their licence texts sit next to them.

## Run it

```bash
# first, in ../secop-api:  npm install && npm start
flutter pub get
flutter test                     # 2 tests
flutter run -d chrome            # web, API at http://localhost:3000
flutter run --dart-define=API_URL=http://10.0.2.2:3000   # Android emulator: 10.0.2.2 is the host machine
flutter build apk --debug
```

`API_URL` is a build-time setting (`--dart-define`). Debug builds on Android allow plain HTTP so they can reach a local API; release builds do not, so a release needs the API on HTTPS.

## Limits

- Verified by analysis, the widget test, a web build checked in a browser against real data, and a debug APK that builds. It has not been run on a physical phone or an emulator, and there is no iOS target.
- No offline mode and no saved entities.
- Only SECOP II: totals are a floor, not all of an entity's contracting.
