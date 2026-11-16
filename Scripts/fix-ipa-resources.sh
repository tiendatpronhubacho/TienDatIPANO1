#!/bin/bash
set -euo pipefail

IPA_PATH="${1:?Usage: fix-ipa-resources.sh path/to/app.ipa}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$IPA_PATH" ]] || { echo "ERROR: IPA not found: $IPA_PATH"; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

/usr/bin/unzip -q "$IPA_PATH" -d "$TMP/unpacked"
APP_PATH="$(find "$TMP/unpacked/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "$APP_PATH" ]] || { echo "ERROR: IPA has no Payload/*.app bundle"; exit 1; }
[[ -f "$APP_PATH/Info.plist" ]] || { echo "ERROR: app bundle has no Info.plist"; exit 1; }
[[ -d "$ROOT/Resources/Assets.xcassets" ]] || { echo "ERROR: Resources/Assets.xcassets is missing"; exit 1; }

# actool requires its output directory to exist before compilation.
mkdir -p "$TMP/compiled-assets"
xcrun actool "$ROOT/Resources/Assets.xcassets" \
  --compile "$TMP/compiled-assets" \
  --platform iphoneos \
  --minimum-deployment-target 16.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$TMP/asset-info.plist"
[[ -s "$TMP/compiled-assets/Assets.car" ]] || { echo "ERROR: actool did not produce Assets.car"; exit 1; }
cp "$TMP/compiled-assets/Assets.car" "$APP_PATH/Assets.car"

# Merge icon metadata emitted by actool.
/usr/bin/python3 - "$APP_PATH/Info.plist" "$TMP/asset-info.plist" <<'PYCODE'
import plistlib, sys
app_path, generated_path = sys.argv[1:]
with open(app_path, 'rb') as f: app = plistlib.load(f)
with open(generated_path, 'rb') as f: generated = plistlib.load(f)
for key in ('CFBundleIcons', 'CFBundleIcons~ipad', 'UIPrerenderedIcon'):
    if key in generated: app[key] = generated[key]
with open(app_path, 'wb') as f: plistlib.dump(app, f, fmt=plistlib.FMT_XML, sort_keys=False)
PYCODE

# Localization.swift uses Bundle.main, so place .lproj folders at the app-bundle root.
if [[ -d "$APP_PATH/Resources" ]]; then
  for langdir in "$APP_PATH"/Resources/*.lproj; do
    [[ -d "$langdir" ]] || continue
    name="$(basename "$langdir")"
    if [[ -e "$APP_PATH/$name" ]]; then
      echo "ERROR: Both root and Resources/$name exist; refusing to overwrite localization data"
      exit 1
    fi
    mv "$langdir" "$APP_PATH/$name"
  done
  rm -rf "$APP_PATH/Resources/Assets.xcassets"
fi
rm -rf "$APP_PATH/Assets.xcassets"

# Validate app identity and executable format before repacking. This output remains unsigned.
/usr/bin/python3 - "$APP_PATH/Info.plist" "$APP_PATH" <<'PYCODE'
import os, plistlib, sys
plist_path, app = sys.argv[1:]
with open(plist_path, 'rb') as f: p = plistlib.load(f)
exe = p.get('CFBundleExecutable')
if not exe or '$(' in exe:
    raise SystemExit(f'ERROR: unresolved CFBundleExecutable: {exe!r}')
binary = os.path.join(app, exe)
if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
    raise SystemExit(f'ERROR: executable missing or not executable: {binary}')
with open(binary, 'rb') as f: magic = f.read(4)
if magic not in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca', b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'):
    raise SystemExit(f'ERROR: executable is not a recognized Mach-O binary (magic={magic.hex()})')
if p.get('CFBundleIdentifier') != 'com.tiendat.ogios':
    raise SystemExit('ERROR: unexpected CFBundleIdentifier')
if p.get('CFBundleDisplayName') != 'TienDat':
    raise SystemExit('ERROR: unexpected CFBundleDisplayName')
if p.get('MinimumOSVersion') not in ('16.0', '16'):
    raise SystemExit(f'ERROR: unexpected MinimumOSVersion: {p.get("MinimumOSVersion")}')
PYCODE

OUT="$TMP/$(basename "${IPA_PATH%.ipa}-resources-fixed.ipa")"
(cd "$TMP/unpacked" && /usr/bin/zip -qry "$OUT" Payload)
mv "$OUT" "$IPA_PATH"
/usr/bin/unzip -t "$IPA_PATH" >/dev/null
echo "Resource fix complete (unsigned IPA): $IPA_PATH"
