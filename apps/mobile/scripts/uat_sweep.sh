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

# Granted once, before the test launches the app. Not in a loop: `simctl
# privacy` terminates the running app every time it is called, so re-granting
# on a timer killed the app every three seconds and the run never progressed.
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
