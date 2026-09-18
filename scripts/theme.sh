#!/usr/bin/env bash
# Switch the whole desktop between the palettes in system/themes/palettes/.
#
# Every themed config is generated from a template by envsubst; the palette is
# the only place a colour is written by hand. See system/themes/README.md.
#
# Usage:
#   theme.sh <name>              apply a theme to the user-level configs
#   theme.sh <name> --system     also rewrite /etc/ly and the Plymouth theme
#   theme.sh --list              one line per theme: name label desc accent base
#   theme.sh --current           print the active theme name
#   theme.sh --check             validate palettes and templates, render nothing
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
THEMES="$REPO/system/themes"
PALETTES="$THEMES/palettes"
TEMPLATES="$THEMES/templates"
ASSETS="$THEMES/assets"
STATE="$THEMES/current"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[35m::\033[0m %s\n' "$*"; }

palette_keys() { grep -oP '^[A-Z][A-Z0-9_]*(?==)' "$1"; }

# Load a palette into the environment and derive the ${VAR}_DEC decimal and
# ${VAR}_BGR byte-swapped forms that a few config formats want. Sets VARLIST to
# the envsubst whitelist. Must NOT run in a subshell the caller depends on: it
# exports the palette into the calling environment.
load_palette() {
	local palette="$1" key value
	VARLIST=""
	set -a
	# shellcheck disable=SC1090
	source "$palette"
	set +a
	for key in $(palette_keys "$palette"); do
		VARLIST+="\$$key "
		value="${!key}"
		if [[ $value =~ ^[0-9a-fA-F]{6}$ ]]; then
			export "${key}_DEC=$((16#$value))"
			# mpv's stats script wants BBGGRR rather than RRGGBB.
			export "${key}_BGR=${value:4:2}${value:2:2}${value:0:2}"
			VARLIST+="\$${key}_DEC \$${key}_BGR "
		fi
	done
}

# render <template-root> <output-root> <varlist> [sudo]
render_tree() {
	local root="$1" out="$2" vars="$3" as_root="${4:-}" src rel dst
	[[ -d $root ]] || return 0
	while IFS= read -r -d '' src; do
		rel="${src#"$root"/}"
		dst="$out/$rel"
		# Rendered through a temp file and moved into place: DMS, niri and
		# Quickshell all watch these files, and a plain redirect truncates
		# first, so a watcher can read a half-written config.
		if [[ -n $as_root ]]; then
			sudo mkdir -p "$(dirname "$dst")"
			envsubst "$vars" < "$src" | sudo tee "$dst.tmp" >/dev/null
			sudo mv -f "$dst.tmp" "$dst"
		else
			mkdir -p "$(dirname "$dst")"
			envsubst "$vars" < "$src" > "$dst.tmp"
			mv -f "$dst.tmp" "$dst"
		fi
	done < <(find "$root" -type f -print0)
}

list_themes() {
	local palette
	for palette in "$PALETTES"/*.env; do
		( load_palette "$palette"
		  printf '%s\t%s\t%s\t#%s\t#%s\n' \
		    "$THEME_NAME" "$THEME_LABEL" "$THEME_DESC" "$ACCENT" "$BASE" )
	done
}

check() {
	local palette reference="" keys missing=0 tmp tmpl var
	# 1. every palette defines exactly the same keys
	for palette in "$PALETTES"/*.env; do
		keys=$(palette_keys "$palette" | sort | tr '\n' ' ')
		if [[ -z $reference ]]; then
			reference="$keys"
		elif [[ $keys != "$reference" ]]; then
			printf 'key mismatch in %s\n  has: %s\n  want: %s\n' \
			  "$(basename "$palette")" "$keys" "$reference" >&2
			missing=1
		fi
	done
	# 2. every variable a template references is defined by every palette
	for tmpl in $(find "$TEMPLATES" -type f); do
		for var in $(grep -oP '\$\{\K[A-Z][A-Z0-9_]*(?=\})' "$tmpl" | sort -u); do
			var="${var%_DEC}"; var="${var%_BGR}"
			if ! grep -q "^$var=" "$PALETTES"/*.env; then
				printf 'undefined %s used by %s\n' "$var" "${tmpl#"$TEMPLATES"/}" >&2
				missing=1
			fi
			for palette in "$PALETTES"/*.env; do
				grep -q "^$var=" "$palette" || {
					printf '%s missing %s (needed by %s)\n' \
					  "$(basename "$palette")" "$var" "${tmpl#"$TEMPLATES"/}" >&2
					missing=1
				}
			done
		done
	done
	# 3. a non-Catppuccin theme must leave no Catppuccin hex behind
	tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
	( load_palette "$PALETTES/tokyonight.env"
	  render_tree "$TEMPLATES/home" "$tmp" "$VARLIST" )
	if grep -rliE '#(1e1e2e|cdd6f4|cba6f7|89b4fa|313244|45475a|11111b|181825)' "$tmp" >/dev/null 2>&1; then
		printf 'Catppuccin hexes survived a tokyonight render in:\n' >&2
		grep -rliE '#(1e1e2e|cdd6f4|cba6f7|89b4fa|313244|45475a|11111b|181825)' "$tmp" >&2
		missing=1
	fi
	# 4. unsubstituted placeholders mean a typo in a template
	if grep -rl '\${' "$tmp" >/dev/null 2>&1; then
		printf 'unsubstituted placeholders in:\n' >&2
		grep -rl '\${' "$tmp" >&2
		missing=1
	fi
	[[ $missing -eq 0 ]] && info "check passed: $(ls "$PALETTES"/*.env | wc -l) palettes, $(find "$TEMPLATES" -type f | wc -l) templates"
	return $missing
}

# Recolour the Plymouth artwork. The source PNGs are near-monochrome, so a flat
# colorize reproduces them faithfully in any palette.
render_plymouth_assets() {
	local out="$1" png name colour
	for png in "$ASSETS"/plymouth/*.png; do
		name=$(basename "$png")
		case "$name" in
			throbber-*) colour="#$ACCENT" ;;
			entry.png)  colour="#$SURFACE0" ;;
			lock.png)   colour="#$OVERLAY0" ;;
			*)          colour="#$TEXT" ;;
		esac
		magick "$png" -fill "$colour" -colorize 100 png:- | sudo tee "$out/$name" >/dev/null
	done
}

apply() {
	local name="$1" system="$2" palette="$PALETTES/$1.env" zen
	[[ -f $palette ]] || die "no such theme: $name (try --list)"
	load_palette "$palette"

	info "rendering $THEME_LABEL"
	render_tree "$TEMPLATES/home" "$REPO/nova" "$VARLIST"

	# Zen keeps its chrome/ inside the profile, outside the stow tree.
	for zen in "$HOME"/.config/zen/*/chrome; do
		[[ -d $zen ]] || continue
		render_tree "$TEMPLATES/apps/zen-browser" "$zen" "$VARLIST"
		info "zen: $(basename "$(dirname "$zen")")"
	done

	if [[ -n $system ]]; then
		info "system files (sudo)"
		render_tree "$TEMPLATES/system" "" "$VARLIST" sudo
		render_plymouth_assets /usr/share/plymouth/themes/nova
		sudo plymouth-set-default-theme -R nova
	fi

	printf '%s\n' "$name" > "$STATE"
	reload
	info "now on $THEME_LABEL"
}

reload() {
	# Niri and Quickshell both watch their files and reload on write.
	command -v bat >/dev/null && bat cache --build >/dev/null 2>&1 || true
	tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
	# DankMaterialShell needs no poke: its theme FileView sets watchChanges and
	# reloads on write. Do NOT clear customThemeFile to force a re-read — an
	# empty path makes DMS JSON.parse("") and toast "Invalid JSON format".
	# ponytail: Ghostty has no reload IPC, so open terminals keep the old
	# palette until ctrl+a>r or a new window. Nothing to do about it here.
}

case "${1:---current}" in
	--list)    list_themes ;;
	--current) cat "$STATE" 2>/dev/null || echo "unknown" ;;
	--check)   check ;;
	-h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//' ;;
	-*)        die "unknown option: $1" ;;
	*)
		system=""
		[[ ${2:-} == --system || ${3:-} == --system ]] && system=1
		apply "$1" "$system"
		;;
esac
