#!/usr/bin/env bash
# Verifies that every Helix API name CodeSnap depends on is still defined by a
# checkout of the Helix Steel branch. Usage: scripts/check-helix-api.sh <helix-checkout>
set -u
helix="${1:?usage: check-helix-api.sh <helix-checkout>}"
here="$(cd "$(dirname "$0")/.." && pwd)"
missing=0
while read -r symbol; do
  [ -z "$symbol" ] && continue
  case "$symbol" in
    key-event-*\?)
      # Registered by a macro as "name" => KeyCode, so look for that table entry.
      key="${symbol#key-event-}"; key="${key%\?}"
      if ! grep -qE "^\s*\"$key\" =>" "$helix/helix-term/src/commands/engine/steel/components.rs"; then
        echo "MISSING: $symbol"; missing=$((missing + 1))
      fi
      continue ;;
  esac
  if ! grep -rqF --include='*.rs' --include='*.scm' -e "$symbol" "$helix/helix-term" "$helix/helix-view" 2>/dev/null; then
    echo "MISSING: $symbol"
    missing=$((missing + 1))
  fi
done < "$here/scripts/helix-api.txt"
if [ "$missing" -gt 0 ]; then
  echo "$missing Helix API names were not found in $helix"
  exit 1
fi
echo "All Helix API names found"
