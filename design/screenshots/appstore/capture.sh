#!/bin/bash
set -e
S="$1"; OUT="$2"
BUNDLE=com.vipinpahwa.WinterArcApp
shoot() {   # udid, label, outdir, launch args...
  local U="$1"; local NAME="$2"; local DIR="$3"; shift 3
  xcrun simctl terminate "$U" $BUNDLE >/dev/null 2>&1 || true
  xcrun simctl launch "$U" $BUNDLE "$@" >/dev/null 2>&1
  sleep 5
  xcrun simctl io "$U" screenshot "$DIR/$NAME.png" >/dev/null 2>&1
  echo "    $NAME"
}
for entry in "47E5B89D-9304-4223-987D-3058ED9F9C54:6.9-inch" \
             "AA4CE328-20DB-400D-B9E4-E0811F9B131D:6.7-inch" \
             "96AAACF7-F641-4748-A183-A1B471178AAD:6.1-inch"; do
  U="${entry%%:*}"; SIZE="${entry##*:}"
  echo "== $SIZE"
  DIR="$OUT/$SIZE"; mkdir -p "$DIR"
  xcrun simctl boot "$U" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$U" -b >/dev/null 2>&1
  xcrun simctl ui "$U" content_size large >/dev/null 2>&1 || true
  xcrun simctl status_bar "$U" override --time "9:41" --batteryState charged \
      --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
  APP=$(find "$S/ddfinal/Build/Products" -name "WinterArcApp.app" -maxdepth 3 | head -1)
  xcrun simctl install "$U" "$APP" >/dev/null 2>&1
  shoot "$U" "1-welcome"  "$DIR" --reset
  shoot "$U" "2-today"    "$DIR" --reset --seed-demo
  shoot "$U" "3-progress" "$DIR" --skip-welcome --tab 1
  shoot "$U" "4-setup"    "$DIR" --reset --skip-welcome
  xcrun simctl shutdown "$U" >/dev/null 2>&1 || true
done
