#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --dir DIR [--editor EDITOR]

Find and edit today's daily note, selecting one if there are multiple matches.

Options:
  --dir DIR        Directory to search recursively (required)
  --editor EDITOR  Editor to open the note with (default: \$EDITOR, then vim)
  -h, --help       Show this help

Searches for daily_YY_MM_DD.md and numbered variants (_2, _3, etc.) in DIR
and its subdirectories. A single match is opened directly; multiple matches
show a numbered picker. No note is created.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

note_dir=""
editor="${EDITOR:-vim}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      [[ $# -ge 2 ]] || die "--dir requires a directory path"
      note_dir="$2"
      shift 2
      ;;
    --dir=*)
      note_dir="${1#--dir=}"
      shift
      ;;
    --editor)
      [[ $# -ge 2 ]] || die "--editor requires an editor command"
      editor="$2"
      shift 2
      ;;
    --editor=*)
      editor="${1#--editor=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$note_dir" ]] || {
  usage >&2
  die "--dir is required"
}

# Expand a leading ~ if the caller quoted the path.
if [[ "$note_dir" == "~" || "$note_dir" == "~/"* ]]; then
  note_dir="${HOME}${note_dir:1}"
fi

[[ -d "$note_dir" ]] || die "directory does not exist: $note_dir"
note_dir="$(cd "$note_dir" && pwd)"
stem="daily_$(date +%y_%m_%d)"

# Preserve paths containing whitespace and report search failures before editing.
match_file="$(mktemp)"
trap 'rm -f "$match_file"' EXIT
find "$note_dir" -type f \( -name "$stem.md" -o -name "${stem}_[0-9]*.md" \) -print0 >"$match_file" || die "could not search $note_dir"
notes=()
while IFS= read -r -d '' candidate; do
  filename="${candidate##*/}"
  if [[ "$filename" == "$stem.md" || "$filename" =~ ^${stem}_[0-9]+\.md$ ]]; then
    notes+=("$candidate")
  fi
done < <(sort -zV "$match_file")
rm -f "$match_file"
trap - EXIT

case "${#notes[@]}" in
  0) die "no daily note for today found under $note_dir" ;;
  1) filepath="${notes[0]}" ;;
  *)
    echo "Today's daily notes:" >&2
    for i in "${!notes[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "${notes[i]#"$note_dir"/}" >&2
    done
    while true; do
      printf 'Select a note (1-%d), or q to cancel: ' "${#notes[@]}" >&2
      IFS= read -r choice || exit 0
      [[ "$choice" != q && "$choice" != Q ]] || exit 0
      # Compare strings to avoid evaluating untrusted input as shell arithmetic.
      filepath=""
      for i in "${!notes[@]}"; do
        if [[ "$choice" == "$((i + 1))" ]]; then
          filepath="${notes[i]}"
          break
        fi
      done
      [[ -z "$filepath" ]] || break
      echo "Invalid selection." >&2
    done
    ;;
esac

exec "$editor" "$filepath"
