#!/usr/bin/env bash
# check-upstreams.sh — are the original sources still online, at the exact commits vendored here?
# Read-only; runs on Linux or macOS. If something is gone, this repository's vendor/ copy is the fallback.
set -uo pipefail
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/upstreams.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
fail=0
check_git() { # name url commit
  local d="$tmp/$1"
  if ! git ls-remote -q "$2" HEAD >/dev/null 2>&1; then printf '  %-24s GONE      %s\n' "$1" "$2"; fail=1; return; fi
  git init -q "$d" && if git -C "$d" fetch -q --depth 1 "$2" "$3" 2>/dev/null; then
    printf '  %-24s ok        %s @ %s\n' "$1" "$2" "${3:0:12}"
  else printf '  %-24s NO-COMMIT %s @ %s (repo online, commit missing)\n' "$1" "$2" "${3:0:12}"; fail=1; fi
}
echo "Upstream sources (vendored copies in vendor/):"
while read -r name commit url; do
  [ -n "$name" ] && check_git "$name" "$url" "$commit"
done < "$KIT/vendor/UPSTREAMS"
url=$(sed -n 's/^apple-pkg //p' "$KIT/vendor/APPLE_PKG")
if curl -fsIL -o /dev/null "$url"; then echo "  EmbeddedOSFirmware.pkg   ok        $url"
else echo "  EmbeddedOSFirmware.pkg   GONE      $url  (not redistributable: keep your own copy)"; fail=1; fi
exit $fail
