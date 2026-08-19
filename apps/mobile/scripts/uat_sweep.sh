#!/usr/bin/env bash
#
# Walks every screen on a simulator and reports what is broken.
#
#   scripts/uat_sweep.sh <simulator-udid> [api-base-url]
#
# Grants the permissions the app asks a golfer for. Without them whole screens
# report themselves broken for a reason that is nothing to do with the app: a
# sweep run without location finds "Cần vị trí để xem điều kiện" on the
# conditions tab and files it as a defect, which trains its reader to ignore
# the report.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: scripts/uat_sweep.sh <simulator-udid> [api-base-url]" >&2
  xcrun simctl list devices available | grep -i iphone >&2 || true
  exit 64
fi

DEVICE="$1"
API_BASE_URL="${2:-https://vps-api.vnteki.com}"
BUNDLE="vnpt.vsp.vspMobile"
cd "$(dirname "$0")/.."

rm -rf /tmp/vsp-uat

echo "==> cycling $DEVICE so its surface repaints"
xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

echo "==> granting location, and standing the golfer on the first tee"
xcrun simctl location "$DEVICE" set "21.035815,105.893826"

# Install first, *then* grant — in that order, and it has to be that order.
#
# `flutter test` uninstalls the app when it finishes, so a grant issued before
# the run is aimed at a bundle that is not on the device. simctl accepts it,
# exits zero, and records nothing; the next run installs a fresh app with no
# TCC entry, and iOS raises its permission alert and waits for a human. That is
# what "vẫn phải bấm" was.
#
# Building the simulator app here is cheap — the test needs the same build, so
# it comes out of the cache — and it gives simctl something real to grant
# against. The TCC entry then survives the reinstall the test does.
echo "==> installing the app so the permission grant has somewhere to land"
if [ -f tool/dev.env ]; then set -a; . tool/dev.env; set +a; fi
flutter build ios --simulator --debug \
  --dart-define=VSP_API_BASE_URL="$API_BASE_URL" \
  ${GOOGLE_SERVER_CLIENT_ID:+--dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID"} \
  >/dev/null 2>&1 || echo "   (build failed; the test will build its own)" >&2
if [ -d build/ios/iphonesimulator/Runner.app ]; then
  xcrun simctl install "$DEVICE" build/ios/iphonesimulator/Runner.app >/dev/null 2>&1 || true
fi
xcrun simctl privacy "$DEVICE" grant location-always "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE" grant photos "$BUNDLE" >/dev/null 2>&1 || true

echo "==> sweeping against $API_BASE_URL"
set +e
flutter test integration_test/uat_sweep_test.dart \
  -d "$DEVICE" \
  --dart-define=VSP_API_BASE_URL="$API_BASE_URL"
status=$?
set -e

shots=$(find /tmp/vsp-uat -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
echo "==> $shots screenshots in /tmp/vsp-uat"
# A sweep that finds defects has done its job, so its exit code is reported
# rather than obeyed: the findings are in the output above.
exit "$status"
