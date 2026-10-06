# FSEP — Flutter Smart Examination Portal

This is the **Laravel backend** for FSEP. It is one half of a two-project
submission — the other half is the **Flutter frontend**, in the sibling
`fsep` folder. This document is the main setup guide for the whole
project; see `fsep/README.md` for a short Flutter-specific pointer back
here.

## 1. Project Overview

FSEP is an online examination platform:

- **Backend:** PHP Laravel REST API, MySQL database, Sanctum token
  authentication.
- **Frontend:** Flutter (Web/Windows/Android/iOS from one codebase).
- **Core features implemented:** login/RBAC (5 roles), exam & question
  bank management, candidate exam delivery with a server-authoritative
  timer/expiry, answer saving, exam submission, automatic grading
  (MCQ/True-False/Short-Answer, negative marking) with manual grading for
  Essay answers, and a persisted per-candidate Result.
- **Three novelty features:**
  1. **Behavioral Cheating Detection** — records focus-loss/navigation
     events during an exam and computes a simple suspicion score.
  2. **AI Question Generator** — generates candidate exam questions using
     **Google Gemini**, subject to examiner review/approval before use.
  3. **Learning Gap Detection** — analyzes a candidate's graded answers
     and reports weak topics.

This README documents only what is actually implemented and verified. It
does not claim features that don't exist (e.g. there is no offline mode,
no push notifications, and no automated grading for Essay/Code Snippet
questions — see [Known Limitations](#10-known-limitations)).

## 2. Requirements

Verified against this project's actual configuration:

| Requirement | Version |
|---|---|
| OS | Windows 10/11 |
| PHP | ^8.3 (tested on 8.3.30) |
| Composer | 2.x |
| MySQL | Any recent MySQL/MariaDB (e.g. via Laragon/XAMPP) |
| Laravel | 13.x (`laravel/framework: ^13.17`) |
| Flutter | 3.41.9 (stable channel) |
| Dart SDK | ^3.11.5 |
| Chrome | Required for the recommended Flutter Web demo target |
| Node.js | **Not required** — this project has no frontend build step |
| Gemini API key | Required only for the AI Question Generator feature |

## 3. Backend Setup

From `C:\laragon\www\fsep-backend`:

```bash
composer install
copy .env.example .env
php artisan key:generate
```

Edit `.env` and configure the database (see [Database Setup](#4-database-setup))
and, optionally, the Gemini key (see [Gemini AI Setup](#5-gemini-ai-setup)).

Then:

```bash
php artisan migrate --seed
php artisan serve --no-reload
```

The backend will be available at:

```
http://127.0.0.1:8000
```

All API routes are under `http://127.0.0.1:8000/api/...`.

## 4. Database Setup

This project uses **MySQL**. Create an empty database before seeding —
`migrate` creates the tables, it does not create the database itself.

In `.env`, set:

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=fsep_backend
DB_USERNAME=root
DB_PASSWORD=
```

Adjust `DB_USERNAME`/`DB_PASSWORD` to match your local MySQL setup (a
default local Laragon/XAMPP MySQL install typically uses `root` with an
empty password, as above).

Once the database exists and `.env` is configured:

```bash
php artisan migrate --seed
```

This creates all tables and runs `database/seeders/DatabaseSeeder.php`,
which seeds the demo accounts, a demo exam, and a completed graded
session (see [Demo Accounts](#7-demo-accounts)). The seeder is safe to
run more than once — it will not create duplicates or reset existing data.

## 5. Gemini AI Setup

The **AI Question Generator** novelty calls the Google Gemini API
server-side. It requires an API key that is **not included** in this
submission.

In `.env`, set:

```
GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE
GEMINI_MODEL=gemini-3.6-flash
```

- Get a key from [Google AI Studio](https://aistudio.google.com/).
- The key is read server-side only (`config('services.gemini.key')`,
  `app/Services/AiQuestionGeneratorService.php`) — it is never sent to
  the Flutter app.
- **Without a valid key, question generation will not work.** The
  endpoint (`POST /api/questions/generate`) returns a clear error
  ("The AI provider is not configured...") instead of crashing — every
  other feature of the platform works normally without this key.

## 6. Flutter Setup

From `C:\laragon\www\fsep`:

```bash
flutter pub get
```

Recommended demo target (works with zero configuration):

```bash
flutter run -d chrome
```

Other targets that exist in this project (`android/`, `ios/`, `windows/`
folders are present):

```bash
flutter run -d windows
```

> **Windows desktop note:** building for Windows requires Visual Studio
> with the "Desktop development with C++" workload installed. On a
> machine without it, `flutter run -d windows` will fail to build — this
> is a Visual Studio requirement, not a bug in the project. `flutter run
> -d chrome` has no such requirement and is the recommended way to
> demonstrate the app.

### Connecting Flutter to the backend

The API base URL is configured in:

```
lib/core/config/app_config.dart
```

- **Flutter Web** automatically uses `http://127.0.0.1:8000/api` and
  needs no changes, as long as the Laravel backend is running on the
  same machine via `php artisan serve`.
- **Windows/Android/iOS** (native, non-web) currently point at a
  hardcoded LAN IP address (`http://192.168.100.13:8000/api`) left over
  from this project's own development machine. **On another machine,
  this must be changed** to either:
  - that machine's own LAN IP (needed for a physical Android/iOS
    device), and start the backend with
    `php artisan serve --host=0.0.0.0` so it's reachable on the network, or
  - `http://127.0.0.1:8000/api`, if only running the Windows desktop
    build on the same machine as the backend.

  Edit the `Environment.development` entry in the `_apiBaseUrls` map in
  that file accordingly.

## 7. Demo Accounts

Created by `database/seeders/DatabaseSeeder.php`. All passwords are
`password123`.

| Role | Email | Password |
|---|---|---|
| System Administrator | `admin@fsep.test` | `password123` |
| Examiner | `testteacher@fsep.test` | `password123` |
| Candidate | `candidate@fsep.test` | `password123` |
| Institutional Administrator | `testinst@fsep.test` | `password123` |
| Live Invigilator | `ali@fsep.test` | `password123` |

**For the demo, the accounts that matter most are `candidate@fsep.test`
(candidate flow), `testteacher@fsep.test` (examiner flow: exam/question
administration, AI generation, manual grading), `admin@fsep.test`
(System Administrator: user management, CSV import, cohort analytics),
and `ali@fsep.test` (Live Invigilator: session monitoring). Only
`testinst@fsep.test` (Institutional Administrator) logs in successfully
without role-specific functional content beyond RBAC demonstration (see
[Known Limitations](#10-known-limitations)).

The seeder also creates one demo exam ("FSEP Demo Exam — Computer
Fundamentals") with an MCQ, True/False, Short Answer, and Essay question,
plus one already-completed, graded session for `candidate@fsep.test` so
Results and Learning Gaps have real data to show immediately.

## 8. Recommended Demo Flow

**A. Candidate** (`candidate@fsep.test`)
1. Log in → Candidate Dashboard → Exams.
2. Open the demo exam → Start/Resume Session (note the countdown timer).
3. Select an MCQ answer, navigate Previous/Next.
4. Submit the exam → see the confirmation screen with the real score and
   per-question correctness.
5. Open Learning Gaps → see the "Computer Basics" weak-topic result
   (already seeded from a prior completed attempt).

**B. Behavioral Cheating Detection**
1. Start a new exam attempt.
2. Switch browser tabs (or minimize the window) once or twice, then
   return.
3. A small status indicator appears in the exam app bar once enough
   events accumulate ("Suspicious"/"Highly Suspicious").

**C. Examiner** (`testteacher@fsep.test`)
1. Log in → Examiner Dashboard → Question Bank.
2. Open the AI Question Generator → enter a topic → Generate (requires a
   configured `GEMINI_API_KEY`) → review and save a generated question.
3. Open Manual Grading → look up the seeded candidate's session/question
   (the seeded Essay answer is already pending review) → enter marks →
   Save.

**D. Results**
- The candidate's Result view shows total score, maximum marks, and
  per-question correctness — with a clear "Pending Manual Review" state
  for any ungraded Essay/Code Snippet answer.

## 9. Novelty Features — What's Actually Implemented

**Behavioral Cheating Detection.** Detects the Flutter app losing/
regaining foreground focus (tab switch, window blur, backgrounding) and
the candidate navigating away from an active exam without submitting.
Each event carries a fixed point value; the cumulative score maps to
Normal / Suspicious / Highly Suspicious. This does **not** use a camera,
does not do real-time streaming, and does not detect anything beyond
these focus/navigation signals.

**AI Question Generator.** Uses the **Google Gemini** API
(`generateContent`, structured JSON output) to generate MCQ, True/False,
Short Answer, or Essay questions from an examiner-supplied topic and
parameters. Every generated question is saved with `review_status =
pending` and `is_ai_generated = true`, and only becomes usable after an
examiner explicitly approves it. Requires `GEMINI_API_KEY` (see
[Gemini AI Setup](#5-gemini-ai-setup)).

**Learning Gap Detection.** After a candidate's answers are graded, this
analyzes their own performance (never another candidate's) grouped by
each question's topic tag, and reports any topic scoring below 70% as a
gap (High if under 50%, Moderate otherwise). It reads real, already-
graded answer data — nothing is precomputed or faked.

## 10. Known Limitations

- **AI generation requires a valid Gemini API key.** Without one, the
  rest of the platform works normally, but no new AI questions can be
  generated.
- **Essay and Code Snippet answers require manual grading** by an
  examiner — there is no automatic essay grading (NLP) and no sandboxed
  code execution.
- **Institutional Administrator dashboard is intentionally minimal**
  (login + logout only) — this role was not assigned functional modules
  in this submission. Live Invigilator, by contrast, is fully
  functional (session monitoring reusing the Behavioral Cheating
  Detection data — see the dashboard's "Live Invigilator" action).
- Several theoretical SRS features (offline-first exam delivery, push
  notifications, PostgreSQL, Docker-based code execution, regex-based
  short-answer grading) were intentionally deferred to protect the
  submission deadline and are not part of this build. PDF/Excel export
  and cohort-level analytics, by contrast, are implemented (Results
  screen export buttons; Examiner/System Administrator dashboard →
  Cohort Analytics) — only *institution*-scoped analytics (there is no
  institution data model in this schema) remains out of scope.
- Windows desktop build requires a local Visual Studio "Desktop
  development with C++" installation — not included in this submission,
  as it's a per-machine toolchain, not project code.

## 11. Troubleshooting

**`composer install` fails**
Confirm PHP 8.3+ and Composer 2.x are installed and on `PATH`
(`php -v`, `composer --version`).

**Database connection failure**
Confirm MySQL is running and `DB_DATABASE`/`DB_USERNAME`/`DB_PASSWORD`
in `.env` match a database you've actually created. Create the database
first — `php artisan migrate` does not create it.

**Laravel server not running / connection refused**
Make sure `php artisan serve` is running in its own terminal and stays
open. Check it's serving on `127.0.0.1:8000` (the terminal output shows
the exact address).

**Flutter dependencies missing**
Run `flutter pub get` from `C:\laragon\www\fsep`. Run `flutter doctor` to
confirm your Flutter install is healthy.

**Flutter cannot connect to the backend**
See [Connecting Flutter to the backend](#connecting-flutter-to-the-backend)
above — this is almost always the hardcoded LAN IP in `app_config.dart`
not matching your machine, or the backend not running.

**"The AI provider is not configured"**
`GEMINI_API_KEY` is missing/empty in the backend's `.env`. Add a real key
and restart `php artisan serve`.

**CORS / cross-origin errors in the browser console**
Confirm the backend is reachable at the exact address Flutter Web is
using (`127.0.0.1:8000` by default) — a connection failure to the wrong
address is often reported by the browser as a CORS-looking error even
though the backend's CORS configuration itself is already permissive.

**Wrong demo credentials**
Use exactly the accounts in [Demo Accounts](#7-demo-accounts) — all
seeded passwords are `password123`. If login fails, confirm
`php artisan migrate --seed` actually completed successfully.

## 12. USB Submission Checklist

**Include:**
- `fsep-backend/` — full Laravel source (`app/`, `routes/`, `database/`
  including `migrations/` and `seeders/`, `config/`, `bootstrap/`,
  `composer.json`, `composer.lock`, `.env.example`, this README)
- `fsep/` — full Flutter source (`lib/`, `test/`, `pubspec.yaml`,
  `pubspec.lock`, its README), including the `android/`, `ios/`,
  `web/`, and `windows/` platform folders if the build targets they
  represent are part of the submission

**Do NOT include** (the evaluator regenerates these):
- `fsep-backend/vendor/` — run `composer install`
- `fsep/build/`, `fsep/.dart_tool/` — run `flutter pub get`
- `node_modules/` — not applicable, this project has none
- `.git/` — not applicable, this project is not a git repository
- `fsep-backend/.env` — contains your real `APP_KEY`, DB credentials,
  and Gemini key; ship only `.env.example`

**Firebase:** this project does not use Firebase/FCM — there is no
Firebase configuration file anywhere in the Flutter project, so nothing
Firebase-related needs to be included.

The evaluator should run `composer install` and `flutter pub get`
themselves after copying the source — see [Backend Setup](#3-backend-setup)
and [Flutter Setup](#6-flutter-setup) above.
