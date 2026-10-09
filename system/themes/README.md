# Theming

One palette drives every application. Switching themes re-renders each themed
config from a template; no colour is written by hand outside a palette file.

```
scripts/theme.sh tokyonight            # user-level configs
scripts/theme.sh tokyonight --system   # also /etc/ly and the boot splash (sudo)
scripts/theme.sh --list                # name, label, description, accent, base
scripts/theme.sh --current             # the active theme
scripts/theme.sh --check               # validate palettes and templates
```

`Mod+Shift+T` opens a front end for the same script: the island's `theme` page
under Hyprland (`nova/.config/quickshell/island/shell.qml`), the standalone
Quickshell picker (`nova/.config/quickshell/theme/`) under niri.

## Layout

| Path | What it is |
|---|---|
| `palettes/<name>.env` | The only hand-written colours. All palettes define the same keys. |
| `templates/home/**` | Rendered into `nova/**`, which stow symlinks into `$HOME`. |
| `templates/apps/zen-browser/**` | Rendered into every Zen profile's `chrome/`, which sits outside the stow tree. |
| `templates/system/**` | Rendered into `/` under `--system`. Needs sudo. |
| `assets/plymouth/*.png` | Boot splash artwork, recoloured per theme with ImageMagick. |
| `current` | One line naming the active theme. Read by `setup.sh`. |

## Adding a theme

Copy an existing palette, change the values, run `scripts/theme.sh --check`.
That is the whole job — no template needs editing, because templates only ever
reference palette keys.

Palettes use Catppuccin's token names (`BASE`, `SURFACE0`, `MAUVE`, `TEXT`, …)
because that is where this palette set started; other themes map their own
colours onto those names. Two tokens holding the same value is fine when a
theme has no distinct equivalent.

Beyond the plain `${TOKEN}` form, `theme.sh` derives two variants for formats
that want something other than `RRGGBB`: `${TOKEN}_DEC` (decimal) and
`${TOKEN}_BGR` (byte-swapped, which mpv's stats script wants).

## How each application is reached

Most configs keep their own settings and pull in a small generated file:
Ghostty (`theme = current`), zsh (`colors.zsh`), fish
(`conf.d/00-theme.fish`), niri (`modules/colors.kdl`, merged into the `layout`
block from `modules/layout.kdl`), rofi (`@import "current"`), Neovim
(`lua/theme.lua`), mpv (`include=`), and qutebrowser
(`theme_colors.py`).

Files that are nothing but colour are generated whole: btop, atuin, television,
eza, fast-syntax-highlighting, swaylock, the bat `.tmTheme`, lazygit, and the
DankMaterialShell theme JSON.

GTK is rendered from `templates/apps/gtk/` into `~/.config/gtk-3.0/` and
`~/.config/gtk-4.0/` (outside the stow tree): `gtk.css` imports
`theme-colors.css`, which uses the same colour mapping DankMaterialShell's
`dank-colors.css` did. Under niri DMS may still rewrite `gtk.css` to import its
own file; both come from the same palette, so the colours agree.
GTK reads its CSS at startup, so an app already running keeps its old colours
until it restarts.

Qt is left to DankMaterialShell's own qt5ct/qt6ct templates and the
`xdgdesktopportal` platform theme; nothing here templates it, and it has not
been verified to follow a switch. `kdeglobals` still names a fixed colour
scheme (`MateriaDark`). The GTK widget theme (`adw-gtk3-dark`) and icon theme
(`breeze-dark`) are likewise fixed — only their colours change.

The seven Quickshell menus share `nova/.config/quickshell/common/Colors.qml`.
Quickshell only auto-registers singletons inside a config's own root, so the
shared one is reached as a QML module: `import common`, which needs
`QML2_IMPORT_PATH=~/.config/quickshell` — set in `hypr/hyprland.lua` (`hl.env`) under
Hyprland and in niri's `modules/environment.kdl` under niri.

## Known gaps

- **Ghostty** has no reload IPC. Open windows keep the old palette until
  `ctrl+a>r` or a new window.
- **Thunderbird** is themed by `catppuccin/thunderbird/mocha-mauve.xpi`, a
  binary extension that cannot be generated from a palette. It stays on
  Catppuccin whatever theme is active.
- **`--system`** runs `plymouth-set-default-theme -R`, which regenerates the
  initramfs and takes a while. That is why it is opt-in rather than part of
  every switch.
