# FSEP — Flutter Frontend

This is the **Flutter frontend** for FSEP (Flutter Smart Examination
Portal). It talks to the Laravel backend in the sibling `fsep-backend`
folder — **see `fsep-backend/README.md` for the full project setup
guide** (backend setup, database, Gemini API key, demo accounts, demo
flow, and known limitations). This file only covers the Flutter side.

## Requirements

- Flutter 3.41.9 (stable channel), Dart SDK `^3.11.5`
- Chrome (recommended demo target — works with no extra configuration)
- The Laravel backend running (see `fsep-backend/README.md`)

## Setup

```bash
flutter pub get
```

Run (recommended):

```bash
flutter run -d chrome
```

Other targets present in this project (`android/`, `ios/`, `windows/`):

```bash
flutter run -d windows
```

> Building for Windows requires Visual Studio with the "Desktop
> development with C++" workload installed on your machine. Without it,
> the Windows build will fail — this is a local toolchain requirement,
> not a project bug. Chrome has no such requirement.

## Connecting to the backend

The API base URL is set in `lib/core/config/app_config.dart`
(`_apiBaseUrls`, `Environment.development` entry):

- **Web** already points at `http://127.0.0.1:8000/api` automatically —
  no change needed, as long as `php artisan serve` is running on the
  same machine.
- **Windows/Android/iOS** currently point at a hardcoded LAN IP from
  this project's original development machine. On a different machine,
  update that entry to your own machine's LAN IP (for a physical mobile
  device, with the backend started via
  `php artisan serve --host=0.0.0.0`) or to `127.0.0.1` (for the Windows
  build running alongside the backend on the same machine).

## Demo accounts

See `fsep-backend/README.md` for the full list. The seeded backend
database provides one account per role (System Administrator, Examiner,
Candidate, Institutional Administrator, Live Invigilator), all with
password `password123`.
