#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --dir DIR [--editor EDITOR]

Create a fresh daily note for today and open it.

Options:
  --dir DIR        Directory to create/open the note in (required)
  --editor EDITOR  Editor to open the note with (default: \$EDITOR, then vim)
  -h, --help       Show this help

The first note is named daily_YY_MM_DD.md. Additional notes use _2, _3, etc.
Existing notes are never overwritten.
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

mkdir -p "$note_dir"
note_dir="$(cd "$note_dir" && pwd)"

stem="daily_$(date +%y_%m_%d)"
filepath="${note_dir}/${stem}.md"
pretty_date="$(date +"%A, %B %d, %Y")"

# Reserve the filename without clobbering another invocation's note.
number=2
while ! (set -o noclobber; printf '# Daily note — %s\n\n' "$pretty_date" >"$filepath") 2>/dev/null; do
  [[ -e "$filepath" || -L "$filepath" ]] || die "could not create note: $filepath"
  filepath="${note_dir}/${stem}_${number}.md"
  number=$((number + 1))
done

exec "$editor" "$filepath"
