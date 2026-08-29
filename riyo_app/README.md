# Riyo Mobile App (Students / Parents)

Flutter app (Android + iOS) for Riyo school. Talks to the JSON API in
`application/controllers/Riyo_api.php` on the Riyo server.

## Setup
1. Install Flutter (https://flutter.dev).
2. From this folder run:
   ```
   flutter create .        # generates android/ and ios/ native projects
   flutter pub get
   ```
3. Open `lib/api_config.dart` and set `BASE_URL` to your Riyo domain
   (e.g. `https://riyo.rf.gd`).

## Run
- Android: `flutter run` (emulator or USB device) or `flutter build apk`
- iOS: `flutter run` (macOS + Xcode) or `flutter build ios`

## Login (test accounts, generated on the server)
- Student/parent: admission no `RYY1000` … `RYY1300`, password `parent123`
  (these are demo rows; create real ones in Riyo admin).
- The app is for students/parents only (the API rejects teacher/admin roles).

## API endpoints (server side)
- `POST /riyo_api/login` (username, password) -> token + student
- `GET  /riyo_api/profile?token=`
- `GET  /riyo_api/attendance?token=`
- `GET  /riyo_api/fees?token=`
- `GET  /riyo_api/notices?token=`
- `GET  /riyo_api/dashboard?token=`

## InfinityFree note
Free InfinityFree hosts inject a one-time JS challenge cookie. In the app,
load the site root once (store cookies) before calling the API, or host the
API on a plan without the challenge. The token itself is valid 24h.
