#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
failed=0
while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file" | tr -d ' ')
  (( lines > 800 )) && { print -u2 "Structure gate: ${file#$root/} has ${lines} lines (limit 800)."; failed=1; }
  types=$(awk '
    { depth += gsub(/\{/, "") - gsub(/\}/, ""); if (depth == 0 && $0 ~ /^[[:space:]]*(public |internal |private |fileprivate )?(final )?(class|struct|enum|actor|extension|protocol)[[:space:]]/) count++ }
    END { print count + 0 }
  ' "$file")
  (( types > 8 )) && { print -u2 "Structure gate: ${file#$root/} declares ${types} top-level types (limit 8)."; failed=1; }
done < <(find "$root/Sources/MarlaApp" -type f -name '*.swift' -print0)
if rg -n '^import (AppKit|SwiftUI)$' "$root/Sources/MarlaApp/Models"; then failed=1; fi
exit $failed
