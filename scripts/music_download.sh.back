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
while IFS= read -r video_url; do
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
