@echo off
for /f "tokens=1,2 delims==" %%a in (.env) do set %%a=%%b

flutter build web --release ^
  --dart-define=FIREBASE_API_KEY=%FIREBASE_API_KEY% ^
  --dart-define=FIREBASE_AUTH_DOMAIN=%FIREBASE_AUTH_DOMAIN% ^
  --dart-define=FIREBASE_DATABASE_URL=%FIREBASE_DATABASE_URL% ^
  --dart-define=FIREBASE_PROJECT_ID=%FIREBASE_PROJECT_ID% ^
  --dart-define=FIREBASE_STORAGE_BUCKET=%FIREBASE_STORAGE_BUCKET% ^
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=%FIREBASE_MESSAGING_SENDER_ID% ^
  --dart-define=FIREBASE_APP_ID=%FIREBASE_APP_ID% ^
  --dart-define=FIREBASE_MEASUREMENT_ID=%FIREBASE_MEASUREMENT_ID%

firebase deploy --only hosting
