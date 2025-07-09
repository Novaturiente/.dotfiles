#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# Usage check
# ------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <YouTube Playlist URL>"
  exit 1
fi

URL="$1"
OUTPUT_DIR=~/Music
URL_LIST=/tmp/video_urls.txt
IDENTIFY_SCRIPT="$(dirname "$0")/identify"

# ------------------------------------------------------------------
# 1) Fetch all video URLs
# ------------------------------------------------------------------
yt-dlp --flat-playlist \
  --print "https://www.youtube.com/watch?v=%(id)s" \
  "$URL" > "$URL_LIST"

# ------------------------------------------------------------------
# 2) Build list of existing files' first words
# ------------------------------------------------------------------
OUTPUT_DIR=$(eval echo "$OUTPUT_DIR")
existing_files_first_words=()
if [[ -d "$OUTPUT_DIR" ]]; then
  for f in "$OUTPUT_DIR"/*; do
    [[ -f "$f" ]] || continue
    first="$(basename "$f" | cut -d' ' -f1)"
    existing_files_first_words+=("$first")
  done
fi

# Serialize the array so it can be imported inside each xargs‐spawned shell
WORDS_SERIALIZED=$(printf '%s:' "${existing_files_first_words[@]}")
export WORDS_SERIALIZED

# ------------------------------------------------------------------
# 3) Define per‐video function
# ------------------------------------------------------------------
process_one() {
  local video_url="$1"
  local video_title word outfile

  # get title only
  video_title=$(yt-dlp --get-title "$video_url" --skip-download)

  # reconstruct array
  IFS=":" read -r -a existing_files_first_words <<< "$WORDS_SERIALIZED"

  # skip if exact first‑word match
  for word in "${existing_files_first_words[@]}"; do
    [[ -z "$word" ]] && continue
    if echo "$video_title" | grep -w -q -- "$word"; then
      echo "[SKIP] \"$video_title\" (found word: $word)"
      return
    fi
  done

  # download & extract audio
  outfile=$(yt-dlp -f bestaudio -x --quiet --no-warnings \
    --audio-format m4a --audio-quality 0 --embed-thumbnail \
    -o "$OUTPUT_DIR/%(title)s.%(ext)s" \
    --print after_move:filepath \
    "$video_url")

  if [[ -f "$outfile" ]]; then
    "$IDENTIFY_SCRIPT" "$outfile"
  else
    echo "[ERROR] failed to download: $video_url"
  fi
}

export -f process_one
export OUTPUT_DIR IDENTIFY_SCRIPT

# ------------------------------------------------------------------
# 4) Parallel execution
# ------------------------------------------------------------------
xargs -a "$URL_LIST" -n1 -P4 -I{} bash -c 'process_one "$@"' _ {}

echo "All downloads and identifications completed."
