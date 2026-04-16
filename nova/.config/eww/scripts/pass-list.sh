#!/usr/bin/env bash
# List password entries as JSON array, optionally filtered
set -euo pipefail

STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
WEB_DIR="$STORE_DIR/web"
FILTER="${1:-}"

# Icon mapping
get_icon() {
    local domain="$1"
    case "$domain" in
        *google*)    echo "" ;;
        *github*)    echo "" ;;
        *gitlab*)    echo "" ;;
        *microsoft*|*outlook*|*live.com*) echo "󰍡" ;;
        *amazon*)    echo "󰸏" ;;
        *digitalocean*) echo "󰣀" ;;
        *facebook*)  echo "" ;;
        *proton*)    echo "󰴈" ;;
        *stripe*)    echo "󰓹" ;;
        *instagram*) echo "" ;;
        *twitter*|*x.com*) echo "" ;;
        *)           echo "󰖟" ;;
    esac
}

[[ ! -d "$WEB_DIR" ]] && echo "[]" && exit 0

entries="["
first=true
while IFS= read -r gpg_file; do
    rel="${gpg_file#$WEB_DIR/}"
    rel="${rel%.gpg}"
    domain="${rel%%/*}"
    user="${rel#*/}"

    # Apply filter
    if [[ -n "$FILTER" ]]; then
        combined="$domain $user"
        if [[ "${combined,,}" != *"${FILTER,,}"* ]]; then
            continue
        fi
    fi

    # Check if has OTP
    has_otp=false
    content=$(pass show "web/$domain/$user" 2>/dev/null) || continue
    echo "$content" | grep -q "^otpauth://" && has_otp=true

    icon=$(get_icon "$domain")

    $first || entries+=","
    first=false
    entries+=$(printf '{"domain":"%s","user":"%s","has_otp":%s,"icon":"%s","entry":"web/%s/%s"}' \
        "$domain" "$user" "$has_otp" "$icon" "$domain" "$user")
done < <(find "$WEB_DIR" -name "*.gpg" -type f | sort)

entries+="]"
echo "$entries"
