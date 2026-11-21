#!/usr/bin/env bash
# check-upstreams.sh — are the original sources still online, at the exact commits vendored here?
# Read-only; runs on Linux or macOS. If something is gone, this repository's vendor/ copy is the fallback.
#   bash check-upstreams.sh              human-readable report
#   bash check-upstreams.sh --markdown   also rewrite the status table in vendor/SOURCES.md
set -uo pipefail
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
MD=0; [ "${1:-}" = --markdown ] && MD=1
tmp=$(mktemp -d "${TMPDIR:-/tmp}/upstreams.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
fail=0
ROWS="$tmp/rows"; : > "$ROWS"
row() { printf '| %s | %s | `%s` | %s |\n' "$1" "$2" "$3" "$4" >> "$ROWS"; }
check_git() { # name url commit
  local d="$tmp/$1"
  if ! git ls-remote -q "$2" HEAD >/dev/null 2>&1; then
    printf '  %-24s GONE      %s\n' "$1" "$2"; row "$1" "$2" "${3:0:12}" "❌ repository gone (vendored copy in use)"; fail=1; return
  fi
  git init -q "$d"
  if git -C "$d" fetch -q --depth 1 "$2" "$3" 2>/dev/null; then
    printf '  %-24s ok        %s @ %s\n' "$1" "$2" "${3:0:12}"; row "$1" "$2" "${3:0:12}" "✅ online"
  else
    printf '  %-24s NO-COMMIT %s @ %s (repo online, commit missing)\n' "$1" "$2" "${3:0:12}"; row "$1" "$2" "${3:0:12}" "⚠️ commit missing upstream"; fail=1
  fi
}
echo "Upstream sources (vendored copies in vendor/):"
while read -r name commit url; do
  [ -n "$name" ] && check_git "$name" "$url" "$commit"
done < "$KIT/vendor/UPSTREAMS"
url=$(sed -n 's/^apple-pkg //p' "$KIT/vendor/APPLE_PKG")
if curl -fsIL -o /dev/null "$url"; then
  echo "  EmbeddedOSFirmware.pkg   ok        $url"; row "EmbeddedOSFirmware.pkg" "Apple CDN" "sha256 0c97ab74" "✅ online"
else
  echo "  EmbeddedOSFirmware.pkg   GONE      $url  (not redistributable: keep your own copy)"
  row "EmbeddedOSFirmware.pkg" "Apple CDN" "sha256 0c97ab74" "❌ gone (not redistributable; use your own copy)"; fail=1
fi
if [ "$MD" = 1 ]; then
  f="$KIT/vendor/SOURCES.md"; blk="$tmp/block"
  {
    echo "<!-- status:start -->"
    echo "Last checked: $(date -u +%Y-%m-%d) (UTC) by check-upstreams.sh."
    echo
    echo "| Source | Upstream | Pinned | Status |"
    echo "| --- | --- | --- | --- |"
    cat "$ROWS"
    echo "<!-- status:end -->"
  } > "$blk"
  awk -v bf="$blk" 'BEGIN{s=0} /<!-- status:start -->/{while((getline l < bf)>0) print l; s=1; next} /<!-- status:end -->/{s=0; next} !s{print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
fi
exit $fail
