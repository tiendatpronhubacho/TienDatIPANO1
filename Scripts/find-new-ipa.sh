#!/bin/bash
set -euo pipefail
MARKER="${1:-.tiendat-build-start}"
if [[ ! -f "$MARKER" ]]; then echo "ERROR: build marker not found: $MARKER" >&2; exit 1; fi
python3 - "$MARKER" <<'PYCODE'
import os, sys
marker = float(open(sys.argv[1]).read().strip())
candidates = []
for base, dirs, names in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in {'.git', '.swiftpm'}]
    for name in names:
        if name.lower().endswith('.ipa'):
            path = os.path.join(base, name)
            try: mtime = os.path.getmtime(path)
            except OSError: continue
            if mtime >= marker - 3:
                candidates.append((mtime, path))
if not candidates:
    raise SystemExit('ERROR: No IPA created or updated by this build was found.')
print(max(candidates)[1])
PYCODE
