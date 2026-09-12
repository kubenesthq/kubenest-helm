#!/usr/bin/env bash
set -euo pipefail

# Refuse a packaged chart archive that contains a .git directory (kn-g8la, kn-zkg5).
#
# THE grep HAS NO -q AND THAT IS THE POINT (kn-ubrk defect 2). Written as
#   tar -tzf "$archive" | grep -Eq '(^|/)\.git(/|$)'
# grep exits at the FIRST match, tar is still writing, tar dies of SIGPIPE, and
# under `set -o pipefail` the pipeline's status becomes 141 — so the `if` is
# FALSE on a DIRTY archive and 1 (also false) on a clean one. The gate could
# never take its refusing branch: the one case it exists for is the one case it
# could not refuse. Dropping -q makes grep consume the whole listing, so tar
# finishes writing and the pipeline's status is grep's own verdict.
#
# THE PRECONDITION, recorded because it cost two failed reproductions: SIGPIPE
# only fires if tar is STILL WRITING when grep exits, so the defect needs .git
# EARLY in a listing long enough to keep tar writing. A small fixture, or one
# with .git last, is the non-firing case and demonstrates nothing.

chart_dir="${1:-.}"

check_archive() {
  local archive="$1"
  if tar -tzf "$archive" | grep -E '(^|/)\.git(/|$)' >/dev/null; then
    echo "refusing chart archive containing .git: $archive" >&2
    return 1
  fi
}

package_and_check() {
  local source="$1" out="$2"
  helm dependency build "$source" >/dev/null
  helm package "$source" --destination "$out" >/dev/null
  local archive
  archive="$(find "$out" -maxdepth 1 -name '*.tgz' -print -quit)"
  test -n "$archive"
  check_archive "$archive"
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

package_and_check "$chart_dir" "$workdir/clean"
echo "PASS: packaged chart contains no .git entries"

if [[ "${2:-}" == "--test-refusal" ]]; then
  fixture="$workdir/fixture"
  mkdir -p "$fixture"
  tar --exclude=.git -C "$chart_dir" -cf - . | tar -C "$fixture" -xf -
  mkdir -p "$fixture/.git"
  printf 'ref: refs/heads/main\n' > "$fixture/.git/HEAD"
  sed -i '/^\.git$/d' "$fixture/.helmignore"

  if package_and_check "$fixture" "$workdir/refusal"; then
    echo "FAIL: .git fixture was accepted" >&2
    exit 1
  fi
  echo "PASS: .git fixture was refused"
fi
