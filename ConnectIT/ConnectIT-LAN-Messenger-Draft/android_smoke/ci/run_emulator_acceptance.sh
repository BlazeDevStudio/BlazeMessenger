#!/usr/bin/env bash
# GitHub android-emulator-runner executes each script input LINE separately.
# Keep all Android acceptance steps in one checked-in Bash process.
set -euo pipefail
test -n "$CONNECTIT_TEST_MASTER_BIN"
test -n "$CONNECTIT_TEST_MASTER_DIR"
test -n "$CONNECTIT_TEST_ACCOUNT"
test -n "$CONNECTIT_TEST_PASSWORD"
test -n "$CONNECTIT_TEST_MASTER_PIN"
test -n "$RUNNER_TEMP"

"$CONNECTIT_TEST_MASTER_BIN" start \
  --dir "$CONNECTIT_TEST_MASTER_DIR" \
  --listen 127.0.0.1:18987 \
  > "$RUNNER_TEMP/connectit-master-emulator.log" 2>&1 &
master_pid=$!
trap 'kill "$master_pid" 2>/dev/null || true' EXIT
ready=0
for _ in $(seq 1 120); do
  if curl --fail --silent --max-time 2 \
      http://127.0.0.1:18987/healthz > /dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.25
done
if [ "$ready" -ne 1 ]; then
  echo 'Disposable Master failed the loopback health check'
  exit 1
fi
adb reverse tcp:18987 tcp:18987
cd ConnectIT/ConnectIT-LAN-Messenger-Draft/android_smoke_build
flutter devices

# Native platform plugin acceptance: NO fake in-memory storage.
flutter test integration_test/connectit_keystore_android_test.dart \
  -d emulator-5554 --reporter expanded

# First app invocation: explicit enrollment with Android-generated key.
# Flutter 3.47+ uninstalls its test APK by default, which deletes the
# Android Keystore wrapping material and encrypted secure-store contents.
# Preserve this exact test APK/data after enrollment for the next invocation.
flutter test integration_test/connectit_emulator_enroll_test.dart \
  -d emulator-5554 --reporter expanded --no-uninstall \
  --dart-define="CONNECTIT_TEST_ACCOUNT=$CONNECTIT_TEST_ACCOUNT" \
  --dart-define="CONNECTIT_TEST_PASSWORD=$CONNECTIT_TEST_PASSWORD" \
  --dart-define="CONNECTIT_TEST_MASTER_PIN=$CONNECTIT_TEST_MASTER_PIN"

# The app MUST still be installed. Do not restore credentials from a file,
# generate a new key, or delete app state to make returning login succeed.
adb shell pm path com.blazedevstudio.connectit_android_smoke > /dev/null
# Separate app process/test invocation: original persisted device only.
adb shell am force-stop com.blazedevstudio.connectit_android_smoke || true
flutter test integration_test/connectit_emulator_returning_test.dart \
  -d emulator-5554 --reporter expanded \
  --dart-define="CONNECTIT_TEST_ACCOUNT=$CONNECTIT_TEST_ACCOUNT" \
  --dart-define="CONNECTIT_TEST_PASSWORD=$CONNECTIT_TEST_PASSWORD" \
  --dart-define="CONNECTIT_TEST_MASTER_PIN=$CONNECTIT_TEST_MASTER_PIN"

python3 - <<'PY'
import os, sqlite3
path = os.path.join(os.environ['CONNECTIT_TEST_MASTER_DIR'],
                    'connectit.sqlite3')
with sqlite3.connect(path) as db:
    count = db.execute('select count(*) from devices').fetchone()[0]
assert count == 1, 'Returning auth must NOT create another device'
print('Android emulator acceptance: exactly one trusted device')
PY
