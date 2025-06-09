#!/usr/bin/env bash

# Function to validate URL format
validate_url() {
    regex='^(http|https|ftp)://[A-Za-z0-9\-\.]+\.[A-Za-z]{2,}(:[0-9]+)?(/.*)?$'
    [[ $1 =~ $regex ]] && return 0 || return 1
}

# Show Rofi input prompt for URL
url=$(rofi -dmenu -theme tokyonight -p "URL :")

# Check if input was provided
if [ -n "$url" ]; then
    # Add https:// if no protocol is specified
    if [[ ! "$url" =~ ^(http|https|ftp):// ]]; then
        url="https://$url"
    fi
    
    # Validate URL
    if validate_url "$url"; then
        qutebrowser "$url"
    else
        url="https://www.google.com/search?hl=en&q=$url"
        qutebrowser "$url"
    fi
fi
