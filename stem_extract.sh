#!/usr/bin/env bash
# macOS/Linux port of stem_extract.bat with recursive directory search
# Requires: ffmpeg, grep, wc

set -u  # Treat unset vars as errors

usage() {
  cat <<'EOF'
Usage:
  stem_extract.sh <file1> [file2 ...]
  stem_extract.sh /d <directory>
  stem_extract.sh -d <directory>
  stem_extract.sh --dir <directory>

Notes:
  - Only .mp4 or .m4a files are processed.
  - Each file must contain exactly 5 audio tracks.
  - Outputs go into "<basename>.stems" with files:
      "<basename> (Stem 0).mp4" ... "(Stem 4).mp4"
  - Directory mode now searches subdirectories recursively.
EOF
}

error() { printf "  Error: %s\n" "$1" >&2; }

# ---- processing for a single file ----
process_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  local base ext ext_lc dir
  base="$(basename "$file")"
  ext=".${base##*.}"
  ext_lc="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"

  if [[ "$ext_lc" != ".mp4" && "$ext_lc" != ".m4a" ]]; then
    error "This script only works on .mp4 or .m4a Stems files: $file"
    return 1
  fi

  local base_no_ext="${base%.*}"
  dir="$(dirname "$file")/${base_no_ext}.stems"

  # Count audio tracks via ffmpeg stream listing
  local trackcount
  trackcount="$(ffmpeg -i "$file" 2>&1 \
    | grep -E "Stream #([0-9]+):([0-9]+).*Audio" \
    | wc -l | tr -d ' ')"

  if [[ "$trackcount" != "5" ]]; then
    error "There must be exactly 5 audio tracks in the file: $file (found $trackcount)"
    return 1
  fi

  if [[ -d "$dir" ]]; then
    echo "Removing existing directory: \"$dir\""
    rm -rf -- "$dir"
  fi

  echo "Creating directory: \"$dir\""
  mkdir -p -- "$dir"

  # Extract 5 audio tracks (0..4)
  local t num trackfile
  for t in 1 2 3 4 5; do
    num=$((t - 1))
    trackfile="$dir/${base_no_ext} (Stem ${num}).mp4"
    if [[ ! -f "$trackfile" ]]; then
      echo "Extracting track ${num} to \"$trackfile\""
      if ! ffmpeg -i "$file" -map 0:a:${num} -c:a copy -vn -sn -y "$trackfile" >/dev/null 2>&1 ; then
        error "Error extracting track ${num} from \"$file\""
      fi
    else
      echo "  Skipping: \"$trackfile\" already exists."
    fi
  done
}

# ---- main argument handling ----
if [[ $# -eq 0 ]]; then
  echo "Please specify one or more .mp4/.m4a files, or use /d [directory]."
  usage
  exit 1
fi

first="$1"
if [[ "$first" == "/d" || "$first" == "-d" || "$first" == "--dir" ]]; then
  shift
  targetdir="${1:-}"
  echo "TARGETDIR is [${targetdir}]"
  if [[ -z "$targetdir" ]]; then
    echo "Please specify a directory after /d."
    exit 1
  fi
  if [[ ! -d "$targetdir" ]]; then
    echo "Directory \"$targetdir\" does not exist."
    exit 1
  fi

  # Recursive search for .mp4 and .m4a files
  mapfile -t files < <(find "$targetdir" -type f \( -iname "*.mp4" -o -iname "*.m4a" \))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No .mp4 or .m4a files found in \"$targetdir\" or its subdirectories."
    exit 0
  fi

  for f in "${files[@]}"; do
    process_file "$f"
  done
else
  for f in "$@"; do
    process_file "$f"
  done
fi
