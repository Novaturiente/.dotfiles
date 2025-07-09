#!/bin/bash

# Check if URL was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube Playlist URL>"
    exit 1
fi

URL="$1"
OUTPUT_DIR=~/Music
URL_LIST="/tmp/video_urls.txt"
IDENTIFY_SCRIPT="$(dirname "$0")/identify"  # script in the same folder

# Step 1: Get individual video URLs
yt-dlp --flat-playlist --print "https://www.youtube.com/watch?v=%(id)s" "$URL" > "$URL_LIST"

# Step 2: Count the number of videos
COUNT=$(wc -l < "$URL_LIST")

# Step 3: Download each video one by one
echo "Starting **$COUNT** downloads to $OUTPUT_DIR/"
OUTPUT_DIR=$(eval echo "$OUTPUT_DIR")

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get the first word of existing files in the output directory
existing_files_first_words=()
if [ -d "$OUTPUT_DIR" ]; then
  for file in "$OUTPUT_DIR"/*; do
    if [ -f "$file" ]; then
      filename=$(basename "$file")
      existing_files_first_words+=("$(echo "$filename" | cut -d ' ' -f 1)")
    fi
  done
fi

while IFS= read -r video_url; do
  # Extract video title from URL
  video_title=$(yt-dlp --get-title "$video_url" --skip-download)

  # Check if the video title contains the first word of any existing file
  skip_download=false
  for word in "${existing_files_first_words[@]}"; do
    if [[ "$video_title" == *"$word"* ]]; then
      echo "Skipping download for \"$video_title\" because it contains \"$word\""
      skip_download=true
      break
    fi
  done

  if $skip_download; then
    continue
  fi

  # Use a temp file to capture final output name
    OUTFILE=$(yt-dlp -f bestaudio -x --quiet --no-warnings \
        --audio-format m4a --audio-quality 0 --embed-thumbnail \
        -o "$OUTPUT_DIR/%(title)s.%(ext)s" \
        --print after_move:filepath \
        "$video_url")
    
    if [ -n "$OUTFILE" ] && [ -f "$OUTFILE" ]; then
        "$IDENTIFY_SCRIPT" "$OUTFILE"
    else
        echo "Failed to download or locate file for: $video_url"
    fi
done < "$URL_LIST"

echo "All downloads and identifications completed."

# Function to check if a video should be skipped
check_if_video_should_be_skipped() {
  local video_title="$1"
  local existing_files_first_words=("$@")

  for word in "${existing_files_first_words[@]}"; do
    if [[ "$video_title" == *"$word"* ]]; then
      echo "Skipping download for \"$video_title\" because it contains \"$word\""
      return 1 # Skip the download
    fi
  done
  return 0 # Do not skip the download
}

