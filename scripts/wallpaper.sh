#!/usr/bin/env bash
while true
do
  DIR="$HOME/Pictures"

  # Create array to store image files
  images=()

  # Find all files and check if they're images
  while IFS= read -r -d '' file; do
      mime_type=$(file --mime-type -b "$file")
      if [[ "$mime_type" == image/* ]]; then
          images+=("$file")
      fi
  done < <(find "$DIR" -maxdepth 1 -type f -print0)

  # Check if any images found
  if [ ${#images[@]} -eq 0 ]; then
      echo "No image files found in $DIR"
      exit 1
  fi

  # Select random image
  random_image="${images[RANDOM % ${#images[@]}]}"

  # Get PID of current swaybg instance (if any)
  OLD_PID=$(pidof swaybg)

  # Start new swaybg instance in background
  swaybg -i "$random_image" -m fill &

  sleep 30m
done
