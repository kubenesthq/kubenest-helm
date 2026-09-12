#!/usr/bin/env bash
set -euo pipefail

# Refuse a committed release tarball that does not match the source it claims to
# be (kn-helm-committed-tgz-drifts-from-source-boiz, kn-tkof).
#
# WHY THIS EXISTS AND IT IS NOT TIDINESS. The committed kubenest-*.tgz files are
# the only 2.x artifacts that exist, and they are what a released-artifact
# install takes. Every other control in this repository reads values.yaml, which
# is SOURCE — so when the artifact and the source diverged, nothing could see it.
# The committed 2.1.0 floated all four image tags and was missing 70 lines its
# own source had, and it stayed that way because a regeneration nobody repeats is
# a STATE, NOT A CONTROL. This is the control.
#
# WHAT IS COMPARED, AND WHY THE TWO EXCLUSIONS ARE NOT LOOPHOLES:
#   charts/      the RESOLVED DEPENDENCY tarballs. Present in every archive by
#                construction and gitignored in source, so they can never match.
#   Chart.yaml   helm REWRITES it canonically when packaging — sorted keys,
#                reflowed block scalars — so a byte comparison always differs
#                even when the content is identical. Measured: the only
#                difference between the packaged and source Chart.yaml at 2.1.0
#                is serialisation. The version is also legitimately overridden
#                for the 2.0.0 archive via `helm package --version`.
# Everything else is compared: values.yaml (where the drift actually was),
# templates/, crds/, sample-values.yaml, .helmignore.
#
# THE VERDICT COMES FROM AN EXIT STATUS AND NEVER FROM SCANNING TEXT (kn-4m8e).
# `x | grep -q pattern` under `set -o pipefail` cannot refuse once the producer
# outgrows the 64 KiB pipe buffer: grep exits at the first match, the producer
# takes SIGPIPE, the pipeline reports 141 and the `if` reads FALSE. This board
# shipped that twice in one night. A values diff is not bounded — 84 lines did
# not reach the threshold, but nothing says the next one will not — so this
# script decides from `diff -r`'s status and pipes nothing into a matcher.
#
# A STATED LIMIT: a file added INSIDE the chart directory that .helmignore also
# excludes would be reported as drift when it is not. That is a false POSITIVE,
# so it fails closed, and the message names the file. Nothing is ignored inside
# kubenest/ today.

chart_dir="${1:-kubenest}"
chart_name="$(basename "$chart_dir")"

refuse() { printf 'REFUSING: %s\n' "$1" >&2; exit 1; }

[ -d "$chart_dir" ] || refuse "no chart directory at ${chart_dir}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# compare_tree <extracted-chart-dir> <label> -> 0 matches, 1 drifted
compare_tree() {
  local extracted="$1" label="$2"
  if diff -r -x charts -x Chart.yaml "$extracted" "$chart_dir" >"$workdir/diff.txt" 2>&1; then
    return 0
  fi
  printf '  DRIFTED  %s\n' "$label" >&2
  # FOR THE READER ONLY. The verdict above is already decided from diff's exit
  # status, so truncating here cannot change it.
  #
  # AND THERE IS NO SIGPIPE RISK HERE, which is worth stating because the same
  # shape elsewhere DOES have one: head is reading a FILE, not the output of a
  # still-running producer, so nothing can die mid-write. The `|| true` is belt
  # and braces rather than load-bearing. (An earlier revision of this comment
  # claimed head SIGPIPEd a cat that does not exist — a comment explaining a
  # mechanism that is not present is worse than no comment.)
  { head -c 4000 "$workdir/diff.txt" || true; } | sed 's/^/      /'
  printf '      ... (%s lines of difference in total)\n' "$(wc -l <"$workdir/diff.txt")" >&2
  return 1
}

check_archive() { # check_archive <tarball>
  # TWO STATEMENTS, NOT ONE. `local a="$1" b="$(f "$a")"` expands every word
  # before performing any assignment, so $a is still unset inside b and `set -u`
  # aborts. Caught by running this against the drifted fixture, not by reading.
  local archive="$1"
  local out="$workdir/x/$(basename "$archive")"
  mkdir -p "$out"
  tar -xzf "$archive" -C "$out" \
    || refuse "could not extract ${archive}"
  [ -d "$out/$chart_name" ] \
    || refuse "${archive} contains no ${chart_name}/ directory — it is not a package of this chart"
  compare_tree "$out/$chart_name" "$archive"
}

shopt -s nullglob
archives=(kubenest-*.tgz)
shopt -u nullglob

# ZERO ARCHIVES IS A REFUSAL, NOT A PASS. "Nothing to check" and "everything
# checked out" must not print the same thing — that is the parked-check shape
# this repository has already been bitten by. If the committed tarballs are
# deliberately removed (see kn-should-committed-tgz-exist-in-kubenest-helm),
# delete this check in the same commit rather than leaving it green over nothing.
if [ ${#archives[@]} -eq 0 ]; then
  refuse "no committed kubenest-*.tgz found at the repository root. If they were removed on purpose, remove this check too."
fi

printf 'comparing %d committed archive(s) against %s/\n' "${#archives[@]}" "$chart_dir"
drifted=0
for a in "${archives[@]}"; do
  if check_archive "$a"; then
    printf '  MATCHES  %s\n' "$a"
  else
    drifted=1
  fi
done

if [ "$drifted" -ne 0 ]; then
  refuse "a committed tarball does not match ${chart_dir}/. Repackage it:
    helm dependency build ${chart_dir} && helm package ${chart_dir} --version <its version> -d ."
fi
printf 'PASS: every committed archive matches %s/\n' "$chart_dir"

# ---------------------------------------------------------------- refusal arm
#
# A CHECK THAT HAS ONLY EVER PASSED IS NOT KNOWN TO REFUSE. This arm builds a
# deliberately drifted archive and requires the comparison above to reject it, so
# every CI run exercises both directions rather than only the one the repository
# happens to be in.
if [ "${2:-}" = "--test-refusal" ]; then
  fixture="$workdir/fixture"
  mkdir -p "$fixture"
  cp -r "$chart_dir" "$fixture/$chart_name"
  printf '\n# drift fixture: a line the source does not have\ndriftProbe: true\n' \
    >>"$fixture/$chart_name/values.yaml"

  if compare_tree "$fixture/$chart_name" "the drift fixture" >/dev/null 2>&1; then
    printf 'FAIL: a drifted fixture was ACCEPTED — this check cannot refuse\n' >&2
    exit 1
  fi
  printf 'PASS: a drifted fixture was refused\n'
fi
