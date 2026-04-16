#!/usr/bin/env bash
# List TOTP entries with live codes and remaining time as JSON
set -euo pipefail

STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
WEB_DIR="$STORE_DIR/web"

get_icon() {
    local name="$1"
    case "${name,,}" in
        *google*)    echo "" ;;
        *github*)    echo "" ;;
        *gitlab*)    echo "" ;;
        *microsoft*|*outlook*) echo "󰍡" ;;
        *amazon*)    echo "󰸏" ;;
        *digitalocean*) echo "󰣀" ;;
        *facebook*)  echo "" ;;
        *proton*)    echo "󰴈" ;;
        *stripe*)    echo "󰓹" ;;
        *instagram*) echo "" ;;
        *twilio*)    echo "󰏲" ;;
        *coolify*)   echo "󰡨" ;;
        *)           echo "󰖟" ;;
    esac
}

[[ ! -d "$WEB_DIR" ]] && echo "[]" && exit 0

now=$(date +%s)
entries="["
first=true

while IFS= read -r gpg_file; do
    rel="${gpg_file#$WEB_DIR/}"
    rel="${rel%.gpg}"
    domain="${rel%%/*}"
    user="${rel#*/}"
    entry="web/$domain/$user"

    content=$(pass show "$entry" 2>/dev/null) || continue
    echo "$content" | grep -q "^otpauth://" || continue

    # Get OTP code
    code=$(pass otp "$entry" 2>/dev/null) || continue

    # Parse period from otpauth URI (default 30)
    period=$(echo "$content" | grep "^otpauth://" | grep -oP 'period=\K[0-9]+' || echo "30")
    period="${period:-30}"
    remaining=$(( period - (now % period) ))

    # Get issuer for display name
    issuer=$(echo "$content" | grep "^otpauth://" | grep -oP 'issuer=\K[^&]+' | head -1)
    issuer=$(printf '%b' "${issuer//%/\\x}")
    [[ -z "$issuer" ]] && issuer="$domain"

    icon=$(get_icon "$issuer")

    $first || entries+=","
    first=false
    entries+=$(printf '{"name":"%s","code":"%s","remaining":%d,"period":%d,"icon":"%s","entry":"%s"}' \
        "$issuer" "$code" "$remaining" "$period" "$icon" "$entry")
done < <(find "$WEB_DIR" -name "*.gpg" -type f | sort)

entries+="]"
echo "$entries"
