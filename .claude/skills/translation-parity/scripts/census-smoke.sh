#!/usr/bin/env bash
# Smoke test for msgid-census.sh itself.
#
# T1 (.reports/accountability-ensurance.md): an automated "Sync the scaffold
# from port-scaffold" commit silently reverted the qualified-receiver and
# Haskell-marker fix to msgid-census.sh, and the regression - the script
# going completely blind to every `Bustle._("...")` call in this tree -
# survived nine commits because nothing in the repo ran the skill's own
# scripts as a check. This script is that check: it censuses this repo's own
# lib/ and exe/, and fails loudly if the count drops to (near) zero despite
# real call sites being present, instead of silently returning nothing the
# way a reverted fix does.
#
# Run it from the repo root: bash .claude/skills/translation-parity/scripts/census-smoke.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
CENSUS="$HERE/msgid-census.sh"

cd "$ROOT"

real_call_sites=$(grep -rE '\bBustle\._\(' lib exe 2>/dev/null | wc -l | tr -d ' ')
rows=$(bash "$CENSUS" lib exe | wc -l | tr -d ' ')

echo "census-smoke: $real_call_sites real Bustle._(...) call sites, $rows census rows" >&2

if [ "$real_call_sites" -eq 0 ]; then
  echo "census-smoke: no Bustle._(...) call sites found to check against - update this smoke test" >&2
  exit 2
fi

if [ "$rows" -lt "$real_call_sites" ]; then
  echo "census-smoke: FAIL - msgid-census.sh returned $rows rows but this tree has" \
       "$real_call_sites real Bustle._(...) call sites. The qualified-receiver fix" \
       "(Bustle._(...)) is missing or has regressed again. See T1 in" \
       ".reports/accountability-ensurance.md and PORTING.md." >&2
  exit 1
fi

echo "census-smoke: OK" >&2
