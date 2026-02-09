#!/bin/bash

# Get list of unstaged files that are not deleted
FILES=$(git diff --name-only --diff-filter=d)

if [ -z "$FILES" ]; then
    echo "No unstaged changes found."
    exit 0
fi

for FILE in $FILES; do
    # Check if file exists and is likely a text file
    if [ -f "$FILE" ]; then
        # Simple check to avoid printing binary files
        if file "$FILE" | grep -q text; then
            echo "$FILE"
            echo '```'
            cat "$FILE"
            
            # Ensure the closing ``` is on a new line
            # tail -c 1 returns the last byte. If it's a newline, it's empty.
            if [ -n "$(tail -c 1 "$FILE")" ]; then
                echo ""
            fi
            
            echo '```'
            echo ""
        fi
    fi
done
