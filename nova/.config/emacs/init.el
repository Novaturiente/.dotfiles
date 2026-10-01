;;; init.el --- minimal Emacs, built up one package at a time -*- lexical-binding: t; -*-

;; ~/.config/emacs is a stow symlink into the dotfiles repo, so everything
;; Emacs writes on its own goes to ~/.cache/emacs instead (see early-init.el).
(setq custom-file (expand-file-name "custom.el" nova-cache)
      backup-directory-alist `(("." . ,(expand-file-name "backups/" nova-cache)))
      auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" nova-cache) t))
      auto-save-list-file-prefix (expand-file-name "auto-save/.saves-" nova-cache)
      savehist-file (expand-file-name "history" nova-cache)
      recentf-save-file (expand-file-name "recentf" nova-cache)
      create-lockfiles nil)
(make-directory (expand-file-name "auto-save/" nova-cache) t)

;; Packages: built-in package.el + use-package, lazy by default. Startup has
;; already activated them from the quickstart file; package.el itself only
;; loads when something needs installing.
(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))
(setq use-package-always-ensure t
      use-package-always-defer t)

;; Basics, mirroring nvim/init.lua (the font is set in early-init.el).
(setq ring-bell-function #'ignore
      use-short-answers t
      display-line-numbers-type 'relative
      scroll-margin 10
      scroll-conservatively 101        ; scroll by lines at the margin, not half a screen
      vc-follow-symlinks t             ; stow symlinks: open the real file without asking
      whitespace-style '(face trailing tab-mark space-mark)
      ;; Like listchars: mark tabs and non-breaking spaces only, not every space.
      whitespace-display-mappings '((tab-mark ?\t [?» ?\t])
                                    (space-mark ?\xA0 [?␣])))
(setq-default tab-width 4)
(defun nova-line-numbers ()
  "Line numbers with Neovim's gap: text starts three columns after the number.
A face box can't pad line numbers (redisplay ignores it there), so the extra
two columns are a line prefix. Wrapped lines get the same two columns: from
`wrap-prefix' on unindented lines, from `visual-wrap' on indented ones."
  (display-line-numbers-mode)
  (setq-local line-prefix "  "
              wrap-prefix "  "
              visual-wrap-extra-indent 2))
(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook #'nova-line-numbers)
  (add-hook hook #'whitespace-mode))
(global-hl-line-mode)
(global-visual-wrap-prefix-mode)       ; breakindent
(global-auto-revert-mode)              ; autoread
(global-so-long-mode)                  ; snacks.bigfile: huge single-line files stay responsive
(savehist-mode)                        ; command history across restarts
(add-hook 'tty-setup-hook #'xterm-mouse-mode) ; graphical frames have the mouse already

;; Buffer tabs along the top (bufferline). Fixed order, so H/L walk them left to
;; right. Each tab is drawn by `nova-tab' at the end of this file.
(setq tab-line-tabs-function #'tab-line-tabs-fixed-window-buffers
      tab-line-tab-name-format-function #'nova-tab
      tab-line-separator ""
      tab-line-new-button-show nil)
(global-tab-line-mode)

;; Leader menu (which-key is built in since Emacs 30).
(setq which-key-idle-delay 0.2)
(which-key-mode)

;; Finder (telescope), built-in: a vertical fuzzy minibuffer, recent files,
;; and project.el for files and grep.
(setq xref-search-program 'ripgrep)
(fido-vertical-mode)
;; Doom's list keys. In find-file (SPC .) fido already acts like Doom's file
;; browser: DEL after a / goes up a directory, RET on a directory enters it.
(keymap-set icomplete-vertical-mode-minibuffer-map "C-j" #'icomplete-forward-completions)
(keymap-set icomplete-vertical-mode-minibuffer-map "C-k" #'icomplete-backward-completions)
;; TAB inserts the highlighted item (a directory is entered) instead of popping
;; up a *Completions* window.
(keymap-set icomplete-vertical-mode-minibuffer-map "TAB" #'icomplete-force-complete)
(recentf-mode)

;; File browser (nvim-tree): dired, opened on the current file with <leader>e.
(setq dired-listing-switches "-alh --group-directories-first"
      dired-kill-when-opening-new-dired-buffer t)

(defun nova-copy-messages ()
  "Copy the *Messages* buffer to the clipboard and show it."
  (interactive)
  (with-current-buffer (messages-buffer)
    (kill-new (buffer-string)))
  (pop-to-buffer (messages-buffer))
  (message "Messages copied to clipboard"))

(defun nova-yank-path (&optional relative)
  "Copy this buffer's absolute file path.
With RELATIVE, copy it relative to the project root, or from ~ outside a project."
  (interactive)
  (let* ((file (or buffer-file-name default-directory))
         (project (and relative (project-current)))
         (path (cond (project (file-relative-name file (project-root project)))
                     (relative (abbreviate-file-name file))
                     (t file))))
    (kill-new path)
    (message "Copied: %s" path)))

(defun nova-yank-relative-path ()
  "Copy this buffer's file path relative to the project root."
  (interactive)
  (nova-yank-path t))

(defun nova-terminal-toggle ()
  "Show or hide the terminal in a bottom split, like Snacks.terminal.toggle."
  (interactive)
  (if-let* ((win (get-buffer-window "*eat*")))
      (quit-window nil win)
    (select-window
     (display-buffer (or (get-buffer "*eat*") (save-window-excursion (eat)))
                     '(display-buffer-at-bottom (window-height . 0.3))))))

(use-package evil
  :demand t
  :init
  ;; Vim behaviour Evil leaves off by default; it must be set before Evil loads.
  (setq evil-undo-system 'undo-redo
        evil-search-module 'evil-search ; persistent search highlights, cleared by Esc
        evil-want-C-u-scroll t
        evil-want-Y-yank-to-eol t
        evil-want-keybinding nil        ; evil-collection provides these instead
        evil-mode-line-format nil       ; the mode line shows the state itself
        evil-split-window-below t
        evil-vsplit-window-right t)
  :config
  (evil-mode 1)
  ;; Keymaps from nvim/lua/config/keymaps.lua and the plugin specs. Leader keys
  ;; live in the motion map so they also work in read-only buffers (help, PDFs).
  (evil-set-leader '(normal visual motion) (kbd "SPC"))
  (evil-define-key 'motion 'global
    (kbd "<leader>w")  #'save-buffer
    (kbd "<leader>q")  #'nova-close-tab      ; like bdelete; the last tab quits
    (kbd "<leader>Q")  #'save-buffers-kill-terminal
    (kbd "<leader>m")  #'nova-copy-messages
    (kbd "<leader>yp") #'nova-yank-path
    (kbd "<leader>yr") #'nova-yank-relative-path
    (kbd "<leader>e")  #'dired-jump
    (kbd "<leader>ff") #'project-find-file
    (kbd "<leader>fg") #'project-find-regexp
    (kbd "<leader>fb") #'switch-to-buffer
    (kbd "<leader>fr") #'recentf-open
    (kbd "<leader>fh") #'describe-symbol
    (kbd "<leader>fk") #'describe-bindings
    (kbd "<leader>/")  #'occur
    (kbd "<leader>tt") #'nova-terminal-toggle
    (kbd "<leader>.")  #'find-file      ; Doom's file browser
    (kbd "<leader>x")  #'scratch-buffer ; Doom's scratch key
    (kbd "<leader>?")  #'which-key-show-major-mode)
  (evil-define-key 'normal 'global
    (kbd "<escape>")   #'evil-ex-nohighlight
    (kbd "H")          #'tab-line-switch-to-prev-tab
    (kbd "L")          #'tab-line-switch-to-next-tab
    ;; Shadows the C-h help prefix in normal state only; F1 still opens help.
    (kbd "C-h")        #'evil-window-left
    (kbd "C-j")        #'evil-window-down
    (kbd "C-k")        #'evil-window-up
    (kbd "C-l")        #'evil-window-right)
  ;; Group names in the leader menu. A (NAME . KEYMAP) binding names the prefix
  ;; for which-key, which never sees the <leader> key name that
  ;; which-key-add-key-based-replacements would match on.
  (dolist (group '(("f" . "find") ("y" . "yank") ("t" . "terminal")))
    (let ((key (kbd (concat "<leader> " (car group)))))
      (define-key evil-motion-state-map key
                  (cons (cdr group) (lookup-key evil-motion-state-map key))))))

;; Vim keys in dired, help, the terminal, PDFs and the rest. Only the modes in
;; use are set up, and SPC is left alone so the leader works everywhere.
(use-package evil-collection
  :demand t
  :init (setq evil-collection-key-blacklist '("SPC"))
  :config
  (evil-collection-init
   '(dired wdired help info eat (pdf pdf-view) markdown-mode (csv csv-mode) which-key xref replace
     buff-menu outline)))

;; jk leaves insert mode. Insert state only, like the imap in Neovim: with Esc
;; rebound above, evil-escape would otherwise also eat j and k in normal state.
(use-package evil-escape
  :demand t
  :init (setq evil-escape-key-sequence "jk"
              evil-escape-excluded-states '(normal visual motion operator replace emacs))
  :config (evil-escape-mode 1))

;; ys/ds/cs to add, delete and change surroundings (mini.surround's sa/sd/sr).
(use-package evil-surround
  :demand t
  :config (global-evil-surround-mode 1))

;; Undo history that survives closing a file (Neovim's undofile).
(use-package undo-fu-session
  :init
  (setq undo-fu-session-directory (expand-file-name "undo/" nova-cache))
  (undo-fu-session-global-mode))

;; File-type icons for the tab line and mode line, drawn from the terminal font
;; (see early-init.el).
(use-package nerd-icons
  :init (setq nerd-icons-font-family nova-font-family))

;; Terminal (Snacks.terminal). Esc returns to normal state; programs that need
;; Esc themselves get it after M-x evil-collection-eat-toggle-send-escape.
(use-package eat
  :init (setq eat-kill-buffer-on-exit t))

;; Completion (blink.cmp): a popup as you type, and the top candidate previewed
;; inline in grey (built in; TAB accepts it). Candidates come from the language
;; server plus words in every visible window, so a pane beside the code feeds
;; its identifiers into completion.
(use-package corfu
  :demand t
  :init (setq corfu-auto t
              corfu-auto-prefix 2
              corfu-cycle t)
  :config (global-corfu-mode))
(global-completion-preview-mode)

(use-package cape
  :demand t
  :init
  ;; ponytail: visible windows of this frame only; widen to all buffers if
  ;; words from hidden buffers are missed.
  (setq cape-dabbrev-buffer-function
        (lambda () (mapcar #'window-buffer (window-list))))
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'nova-line-capf))

(defun nova-line-capf ()
  "Complete the whole current line from lines in the other visible windows.
Typing the start of a line shown in another pane previews the rest of that
line. Returns nothing when no line matches, so word completion
takes over."
  ;; ponytail: replaces from the indentation to point, so text after point
  ;; (an auto-closed paren) stays and may double up.
  (let* ((start (save-excursion (back-to-indentation) (point)))
         (typed (buffer-substring-no-properties start (point)))
         lines)
    (when (>= (length typed) 2)
      (dolist (buf (delete (current-buffer) (mapcar #'window-buffer (window-list))))
        (with-current-buffer buf
          (save-excursion
            (goto-char (point-min))
            (while (search-forward typed nil t)
              (let ((line (string-trim (buffer-substring-no-properties
                                        (line-beginning-position) (line-end-position)))))
                (when (and (string-prefix-p typed line) (not (equal typed line)))
                  (push line lines)))
              (forward-line 1)))))
      (when lines
        (list start (point) (delete-dups lines) :exclusive 'no)))))

;; LSP (nvim-lspconfig), built in. Same servers as lsp.lua. The server's
;; candidates are merged with the window words, like blink's lsp + buffer.
(defun nova-eglot-capf ()
  (when (eglot-managed-p)
    (setq-local completion-at-point-functions
                (list #'nova-line-capf
                      (cape-capf-super #'eglot-completion-at-point #'cape-dabbrev)
                      #'cape-file))))

;; Rust and Go have no mode until their tree-sitter grammar exists. Emacs 31
;; pins each grammar's source and builds it on first use; this builds it
;; without asking, into the cache rather than the repo.
(setq treesit-auto-install-grammar 'always
      treesit-extra-load-path (list (expand-file-name "tree-sitter" nova-cache)))
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
(add-to-list 'auto-mode-alist '("\\.go\\'" . go-ts-mode))
(add-to-list 'auto-mode-alist '("/go\\.mod\\'" . go-mod-ts-mode))

(use-package eglot
  :ensure nil
  :hook (((python-mode python-ts-mode rust-mode rust-ts-mode go-mode go-ts-mode
           sh-mode bash-ts-mode c-mode c-ts-mode c++-mode c++-ts-mode lua-mode lua-ts-mode)
          . eglot-ensure)
         (eglot-managed-mode . nova-eglot-capf))
  :init
  (evil-define-key 'normal 'global
    (kbd "<leader>lr") #'eglot-rename
    (kbd "<leader>la") #'eglot-code-actions))

;; Markdown rendered in place: markup hidden, headings sized. Tab folds the
;; section under the cursor and Shift-Tab cycles the whole outline.
(use-package markdown-mode
  :init (setq markdown-hide-markup t
              markdown-header-scaling t
              markdown-fontify-code-blocks-natively t)
  :config
  (evil-define-key 'normal markdown-mode-map
    (kbd "TAB")        #'markdown-cycle
    (kbd "<tab>")      #'markdown-cycle
    (kbd "<backtab>")  #'markdown-shifttab
    (kbd "<leader>um") #'markdown-toggle-markup-hiding))

;; PDFs rendered by pdf-tools. Its epdfinfo server is built into the package
;; directory by `pdf-tools-install'; the loader defers everything to the first PDF.
(use-package pdf-tools
  :init
  (pdf-loader-install)
  ;; q closes the tab like SPC q, instead of quit-window, which leaves *Messages*.
  (evil-define-key 'normal 'pdf-view-mode-map "q" #'nova-close-tab))

;; CSV and TSV open as an aligned table with the first row pinned as a header.
(defun nova-csv-preview ()
  "Show a CSV buffer as an aligned table."
  (csv-guess-set-separator)
  (csv-align-mode)
  (csv-header-line))

(use-package csv-mode
  :hook (csv-mode . nova-csv-preview))

;; Colours come from the palette via scripts/theme.sh, which renders theme.el.
;; theme.el loads the theme itself, so the package is only ensured here.
(use-package catppuccin-theme)
(load (locate-user-emacs-file "theme.el") nil t)

;;; Neovim look ---------------------------------------------------------------
;; catppuccin.nvim, lualine and bufferline all colour from the same palette as
;; the theme above, but pick different slots and blend some of them. Their rules
;; are copied here so both editors match on every theme.sh palette.

(defun nova-c (name)
  "The palette colour NAME, e.g. `base' or `blue'."
  (catppuccin-color name))

(defun nova-rgb (hex)
  (mapcar (lambda (i) (string-to-number (substring hex i (+ i 2)) 16)) '(1 3 5)))

(defun nova-mix (fg bg alpha)
  "FG laid over BG at ALPHA, catppuccin.nvim's `darken'."
  (apply #'format "#%02x%02x%02x"
         (seq-mapn (lambda (f b) (floor (+ (* alpha f) (* (- 1 alpha) b) 0.5)))
                   (nova-rgb fg) (nova-rgb bg))))

(defun nova-shade (hex percent)
  "HEX scaled by PERCENT, bufferline's `shade_color'."
  (apply #'format "#%02x%02x%02x"
         (mapcar (lambda (v) (min 255 (floor (* v (+ 100 percent)) 100)))
                 (nova-rgb hex))))

(custom-theme-set-faces
 'user
 ;; Editor. Where catppuccin.nvim and catppuccin-theme disagree, Neovim wins.
 `(hl-line ((t :background ,(nova-mix (nova-c 'surface0) (nova-c 'base) 0.64))))
 `(region ((t :background ,(nova-c 'surface1) :weight bold :extend t)))
 `(font-lock-comment-face ((t :foreground ,(nova-c 'overlay2) :slant italic)))
 `(font-lock-doc-face ((t :inherit font-lock-comment-face)))
 `(font-lock-builtin-face ((t :foreground ,(nova-c 'peach))))
 `(font-lock-preprocessor-face ((t :foreground ,(nova-c 'pink))))
 `(font-lock-property-name-face ((t :foreground ,(nova-c 'lavender))))
 `(font-lock-property-use-face ((t :foreground ,(nova-c 'lavender))))
 `(show-paren-match ((t :foreground ,(nova-c 'peach) :weight bold
                        :background ,(nova-mix (nova-c 'surface1) (nova-c 'base) 0.7))))
 `(isearch ((t :foreground ,(nova-c 'mantle) :background ,(nova-c 'red) :weight normal)))
 `(lazy-highlight ((t :foreground ,(nova-c 'text)
                      :background ,(nova-mix (nova-c 'sky) (nova-c 'base) 0.3))))
 `(whitespace-tab ((t :foreground ,(nova-c 'surface1) :background unspecified)))
 `(whitespace-space ((t :foreground ,(nova-c 'surface1) :background unspecified)))
 `(whitespace-trailing ((t :foreground unspecified :background ,(nova-c 'surface1))))
 `(vertical-border ((t :foreground ,(nova-c 'crust))))
 ;; Finder, like telescope's selection and matches.
 `(icomplete-selected-match ((t :foreground ,(nova-c 'text) :background ,(nova-c 'surface0) :weight bold)))
 `(completions-common-part ((t :foreground ,(nova-c 'blue))))
 ;; Markdown, like treesitter's markup groups and render-markdown's code blocks.
 `(markdown-url-face ((t :foreground ,(nova-c 'blue) :slant italic :underline t)))
 `(markdown-list-face ((t :foreground ,(nova-c 'teal))))
 `(markdown-bold-face ((t :foreground ,(nova-c 'red) :weight bold)))
 `(markdown-italic-face ((t :foreground ,(nova-c 'red) :slant italic)))
 `(markdown-code-face ((t :background ,(nova-c 'surface0) :extend t)))
 ;; lualine's middle section and bufferline's fill, in the editor font.
 `(mode-line ((t :foreground ,(nova-c 'text) :background ,(nova-c 'mantle)
                 :box nil :overline nil :underline nil)))
 `(mode-line-inactive ((t :foreground ,(nova-c 'overlay0) :background ,(nova-c 'mantle)
                          :box nil :overline nil :underline nil)))
 `(tab-line ((t :inherit default :height 1.0 :box nil :foreground ,(nova-c 'overlay2)
                :background ,(nova-shade (nova-c 'base) -45)))))

;; Tab line: bufferline's thin style.
(defun nova-tab (tab _tabs)
  "Draw TAB like bufferline: indicator, icon and name padded to 18 columns,
a close button (or a green dot when modified), then a thin separator."
  (let* ((selected (eq tab (window-buffer)))
         (bg (if selected (nova-c 'base) (nova-shade (nova-c 'base) -25)))
         (fg (nova-c (if selected 'text 'overlay2)))
         (icon (with-current-buffer tab
                 (if buffer-file-name
                     (nerd-icons-icon-for-file buffer-file-name)
                   (nerd-icons-icon-for-mode major-mode))))
         (body (concat (if (stringp icon) (concat icon " ") "")
                       (string-replace "%" "%%" (buffer-name tab))))
         (pad (make-string (max 1 (/ (- 18 (string-width body)) 2)) ?\s))
         (label (concat pad body pad))
         (modified (and (buffer-file-name tab) (buffer-modified-p tab))))
    ;; Appended, so the icon keeps its own colour and takes the tab's background.
    (add-face-text-property 0 (length label)
                            `(:foreground ,fg :background ,bg
                              ,@(and selected '(:weight bold :slant italic)))
                            t label)
    (propertize
     (concat (propertize (if selected "▎" " ") 'face `(:foreground ,(nova-c 'text) :background ,bg))
             (propertize label 'keymap tab-line-tab-map 'follow-link 'ignore)
             (propertize (if modified " ● " "  ")
                         'face `(:foreground ,(if modified (nova-c 'green) fg) :background ,bg)
                         'keymap tab-line-tab-close-map)
             (propertize "▏" 'face `(:foreground ,(nova-shade (nova-c 'base) -45) :background ,bg)))
     'tab tab 'mouse-face 'tab-line-highlight)))

;; Mode line: lualine with section_separators = "" and the sections from
;; nvim/lua/plugins/lualine.lua (mode | branch | path ... filetype | progress | location).
(defun nova-ml-state ()
  "lualine's name and palette colour for the current Evil state."
  (pcase evil-state
    ('insert (cons (if (derived-mode-p 'eat-mode) "TERMINAL" "INSERT") 'green))
    ('visual (cons (pcase evil-visual-selection ('line "V-LINE") ('block "V-BLOCK") (_ "VISUAL"))
                   'mauve))
    ('replace '("REPLACE" . red))
    ('emacs '("EMACS" . peach))
    (_ '("NORMAL" . blue))))

(defun nova-ml-faces ()
  "lualine's section a and b faces for the current Evil state."
  (let* ((state (nova-ml-state))
         (colour (nova-c (cdr state))))
    (list (car state)
          `(:foreground ,(nova-c (if (equal (car state) "NORMAL") 'mantle 'base))
            :background ,colour :weight bold)
          `(:foreground ,colour :background ,(nova-c 'surface0)))))

(defvar-local nova-ml-file nil
  "(PATH . BRANCH) for this buffer's file, worked out once when first shown.")

(defun nova-ml-file ()
  "The file's path relative to its project root (lualine's path = 1) and the
repository's branch. The branch comes from .git/HEAD, so it also shows for
files Git doesn't track yet."
  (or nova-ml-file
      (setq nova-ml-file
            (let* ((project (project-current))
                   (root (and project (project-root project)))
                   (head (and root (expand-file-name ".git/HEAD" root))))
              (cons (if root
                        (file-relative-name buffer-file-name root)
                      (abbreviate-file-name buffer-file-name))
                    (and head (file-regular-p head)
                         (with-temp-buffer
                           (insert-file-contents head)
                           (and (looking-at "ref: refs/heads/\\(.+\\)")
                                (match-string 1)))))))))

(defun nova-ml-path ()
  (string-replace "%" "%%" (if buffer-file-name (car (nova-ml-file)) (buffer-name))))

(defun nova-ml-branch ()
  "Emacs's live Git status for tracked files, else the branch read at open."
  (or (and vc-mode (string-match "Git[-:!?@]\\(.+\\)" vc-mode) (match-string 1 vc-mode))
      (and buffer-file-name (cdr (nova-ml-file)))))

(defun nova-ml-left ()
  (if (not (mode-line-window-selected-p))
      (concat " " (nova-ml-path))
    (pcase-let ((`(,name ,a ,b) (nova-ml-faces))
                (branch (nova-ml-branch)))
      (concat (propertize (concat " " name " ") 'face a)
              (and branch (propertize (concat "  " branch " ") 'face b))
              " " (nova-ml-path)
              (cond (buffer-read-only " [-]") ((buffer-modified-p) " [+]"))))))

(defun nova-ml-right ()
  (if (not (mode-line-window-selected-p))
      " %l:%C "
    (pcase-let ((`(,_ ,a ,b) (nova-ml-faces))
                (icon (nerd-icons-icon-for-mode major-mode)))
      (concat (and (stringp icon) (concat icon " "))
              (replace-regexp-in-string "\\(-ts\\)?-mode\\'" "" (symbol-name major-mode)) " "
              (propertize (concat " " (cond ((= (line-beginning-position) (point-min)) "Top")
                                            ((= (line-end-position) (point-max)) "Bot")
                                            (t (format "%2d%%%%" (/ (* 100 (point)) (point-max)))))
                                  " ")
                          'face b)
              ;; %l keeps redisplay's cached line count; the column is left-aligned like %-2v.
              (propertize (format " %%3l:%-2d " (1+ (current-column))) 'face a)))))

(setq-default mode-line-format
              '((:eval (nova-ml-left)) mode-line-format-right-align (:eval (nova-ml-right))))

;;; Dashboard -----------------------------------------------------------------
;; snacks.nvim's dashboard: logo, the keys from nvim/lua/plugins/snacks.lua and
;; a startup line, in snacks' colours. Shown when Emacs starts without a file.
;; ponytail: hand-drawn, not the dashboard package; it has no more than this.

(defconst nova-dashboard-logo "\
███████╗███╗   ███╗ █████╗  ██████╗███████╗
██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
█████╗  ██╔████╔██║███████║██║     ███████╗
██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝")

(defconst nova-dashboard-keys
  `(("f" "" "Find File" project-find-file)
    ("n" "" "New File" ,(lambda () (interactive)
                                (switch-to-buffer (generate-new-buffer "untitled"))
                                (text-mode)
                                (evil-insert-state)))
    ("g" "" "Live Grep" project-find-regexp)
    ("r" "" "Recent Files" recentf-open)
    ("e" "" "File Explorer" dired-jump)
    ("c" "" "Config" ,(lambda () (interactive)
                              (let ((default-directory user-emacs-directory))
                                (call-interactively #'find-file))))
    ("L" "\U000f04b2" "Packages" package-list-packages-no-fetch)
    ("q" "" "Quit" save-buffers-kill-terminal))
  "(KEY ICON DESCRIPTION COMMAND) for each dashboard row.")

(define-derived-mode nova-dashboard-mode special-mode "Dashboard"
  "The start screen."
  (setq-local evil-motion-state-cursor '(nil)) ; the line highlight marks the selection
  (add-hook 'window-size-change-functions #'nova-dashboard-render nil t))
(put 'nova-dashboard-mode 'tab-line-exclude t) ; no tab bar, and never a tab
(setq tab-line-tabs-window-buffers-filter-function #'tab-line-tabs-non-excluded)
(evil-set-initial-state 'nova-dashboard-mode 'motion)
(evil-define-key 'motion nova-dashboard-mode-map
  (kbd "j") #'forward-button
  (kbd "k") #'backward-button
  (kbd "RET") #'push-button)
(pcase-dolist (`(,key ,_ ,_ ,command) nova-dashboard-keys)
  (evil-define-key 'motion nova-dashboard-mode-map (kbd key) command))

(defun nova-dashboard-render (&optional window)
  "Draw the dashboard centred in WINDOW: rows 60 columns wide, like snacks."
  (let* ((window (or window (selected-window)))
         (logo (split-string nova-dashboard-logo "\n"))
         (height (+ (length logo) 1 (* 2 (length nova-dashboard-keys)) 1))
         (face (lambda (colour &rest attrs) `(:foreground ,(nova-c colour) ,@attrs)))
         ;; :align-to keeps rows centred as the window resizes, without a redraw.
         (indent (lambda (width) (propertize " " 'display `(space :align-to (- center ,(/ width 2))))))
         (packages (length package-activated-list))
         (loaded (seq-count #'featurep package-activated-list))
         (inhibit-read-only t))
    (with-current-buffer (window-buffer window) ; the resize hook runs from any buffer
      (erase-buffer)
      (insert (make-string (max 0 (/ (- (window-body-height window) height) 2)) ?\n))
      ;; Emacs draws box and block characters from the font, unlike Ghostty, and
      ;; Iosevka-style fonts leave gaps around them; JetBrains Mono's fill the
      ;; cell. The indent shares the face so the rows are its height and touch.
      (dolist (line logo)
        (insert (propertize (concat (funcall indent (string-width line)) line "\n")
                            'face (funcall face 'blue :family "JetBrainsMonoNL Nerd Font"))))
      (insert "\n")
      (pcase-dolist (`(,key ,icon ,desc ,command) nova-dashboard-keys)
        (insert (funcall indent 60))
        (insert-text-button
         (concat (propertize (concat icon " ") 'face (funcall face 'pink :weight 'bold))
                 (propertize desc 'face (funcall face 'blue))
                 (propertize " " 'display '(space :align-to (+ center 29)) 'face 'default)
                 (propertize key 'face (funcall face 'peach)))
         'action (lambda (_) (call-interactively command)))
        (insert "\n\n"))
      (let ((footer (format "⚡ Emacs loaded %d/%d packages in %.0fms" loaded packages
                            (* 1000 (float-time (time-subtract after-init-time before-init-time))))))
        (insert (funcall indent (string-width footer))
                (propertize footer 'face (funcall face 'yellow :slant 'italic))))
      (goto-char (point-min))
      (forward-button 1)
      (set-window-point window (point)))))

(defun nova-dashboard ()
  "Show the dashboard and return its buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*dashboard*")))
    (switch-to-buffer buffer)
    (unless (derived-mode-p 'nova-dashboard-mode) (nova-dashboard-mode))
    (nova-dashboard-render)
    buffer))

;; After startup has shown any files or directories it was given (the MIME
;; defaults open files this way), so only an empty start gets the dashboard.
;; *scratch* always goes, or it would stay behind as a tab; SPC x brings it back.
(add-hook 'emacs-startup-hook
          (lambda ()
            (when (equal (buffer-name) "*scratch*")
              (nova-dashboard))
            (when (get-buffer "*scratch*")
              (kill-buffer "*scratch*"))))

;; The daemon starts once with no frame, so each empty `emacsclient -c' frame
;; asks for its buffer here instead. Daemon only: in a plain `emacs FILE' this
;; would split the window to show the dashboard beside the file.
(when (daemonp)
  (setq initial-buffer-choice #'nova-dashboard))

(defun nova-close-tab ()
  "Close the current tab. The window's last tab closes the window too, and
the last tab of the last window quits Emacs."
  (interactive)
  (cond ((cdr (funcall tab-line-tabs-function)) (kill-current-buffer))
        ((one-window-p) (save-buffers-kill-terminal))
        ((kill-current-buffer) (delete-window))))
