#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --dir DIR [--editor EDITOR]

Create today's daily note (if it does not already exist) and open it.

Options:
  --dir DIR        Directory to create/open the note in (required)
  --editor EDITOR  Editor to open the note with (default: \$EDITOR, then vim)
  -h, --help       Show this help

The note is named daily_YY_MM_DD.md. If today's file already exists, it is
opened as-is without changing its contents.
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

filename="daily_$(date +%y_%m_%d).md"
filepath="${note_dir}/${filename}"
pretty_date="$(date +"%A, %B %d, %Y")"

if [[ -e "$filepath" && ! -f "$filepath" ]]; then
  die "path exists but is not a regular file: $filepath"
fi

if [[ ! -f "$filepath" ]]; then
  printf '# Daily note — %s\n\n' "$pretty_date" >"$filepath"
fi

exec "$editor" "$filepath"
