#!/usr/bin/env bash
# Wipe local Memos One data so the next launch behaves like first install (macOS).
set -euo pipefail

BUNDLE_ID="com.example.memosOne"
BASE="${HOME}/Library/Containers/${BUNDLE_ID}/Data"

# Stop app (exact process name only)
if pgrep -x memos_one >/dev/null 2>&1; then
  kill "$(pgrep -x memos_one)" 2>/dev/null || true
  sleep 0.4
fi

if [[ -d "${BASE}" ]]; then
  rm -rf "${BASE}/Library/Application Support/"* 2>/dev/null || true
  rm -f "${BASE}/Library/Preferences/${BUNDLE_ID}.plist" 2>/dev/null || true
  rm -rf "${BASE}/Library/Caches" "${BASE}/Library/HTTPStorages" \
    "${BASE}/Library/Cookies" "${BASE}/tmp" 2>/dev/null || true
  echo "Cleared sandbox Data under Containers/${BUNDLE_ID}"
else
  echo "No sandbox Data found (already clean or never launched)."
fi

defaults delete "${BUNDLE_ID}" 2>/dev/null || true
rm -f "${HOME}/Library/Preferences/${BUNDLE_ID}.plist" 2>/dev/null || true

# Only remove our workspace.* access tokens (do not wipe whole flutter_secure_storage)
python3 - <<'PY'
import re, subprocess
out = subprocess.run(["security", "dump-keychain"], capture_output=True, text=True).stdout
n = 0
for b in out.split("keychain:"):
    if "flutter_secure_storage_service" not in b:
        continue
    m = re.search(r'"acct"<blob>="([^"]+)"', b)
    if not m:
        continue
    acct = m.group(1)
    if acct.startswith("workspace.") and "accessToken" in acct:
        r = subprocess.run(
            ["security", "delete-generic-password",
             "-s", "flutter_secure_storage_service", "-a", acct],
            capture_output=True, text=True,
        )
        if r.returncode == 0:
            n += 1
            print(f"Removed keychain account {acct}")
print(f"Workspace tokens removed: {n}")
PY

echo "Done. Next launch = first-run onboarding."
echo "open build/macos/Build/Products/Release/memos_one.app"
