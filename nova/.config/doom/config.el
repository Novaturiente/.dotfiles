(require 'hideshow)
(setq doom-font (font-spec :family "JetBrains Mono NL Nerd Font" :size 15))
(when (display-graphic-p)
  (set-face-attribute 'default nil :weight 'semibold))

;; (add-to-list 'custom-theme-load-path "~/.doom.d/themes")
;; (load-theme 'doom-rose-pine t)
;; (setq doom-theme 'doom-challenger-deep)


(set-frame-parameter nil 'alpha-background 80)
(add-to-list 'default-frame-alist '(alpha-background . 80))

(setq display-line-numbers-type t)
(setq comint-terminal-type "xterm-256color")
(setq vterm-shell "/usr/bin/zsh")
(add-hook 'emacs-startup-hook #'vterm)
(add-hook 'after-init-hook #'spacious-padding-mode)

(add-hook 'after-make-frame-functions #'spacious-padding-mode)

(setq confirm-kill-emacs nil)
(setq confirm-kill-processes nil)

(map! :leader
      :desc "Kill buffer" "q w" #'kill-current-buffer)
(map! :leader
      :desc "change window" "<left>" #'evil-window-left)
(map! :leader
      :desc "change window" "<right>" #'evil-window-right)

;; Unset existing bindings & Set M-<left> and M-<right> to switch buffers
(global-unset-key (kbd "M-<left>"))
(global-unset-key (kbd "M-<right>"))
(global-set-key (kbd "M-<left>") #'previous-buffer)
(global-set-key (kbd "M-<right>") #'next-buffer)

(defun close-window-and-kill-buffer ()
  "Kill the buffer associated with the current window and then close the window."
  (interactive)
  (kill-buffer)
  (delete-window))

(map! :leader
      :prefix "w"
      :desc "Close window and kill buffer"
      "w" #'close-window-and-kill-buffer)

;; Open a vterm in a new vertical split window.
(defun my/vterm-open-vertical-split ()
  (interactive)
  (let ((buffer (generate-new-buffer "*vterm*")))
    (split-window-right)
    (other-window 1)
    (switch-to-buffer buffer)
    (vterm-mode)))

(map! :leader
      (:prefix "t"
       :desc "Open vterm in vertical split" "t" #'my/vterm-open-vertical-split))

(setq vterm-kill-buffer-on-exit t)
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Force TAB to insert two spaces in programming modes
(after! prog-mode
  (map! :map prog-mode-map
        :i [tab] (lambda () (interactive) (insert "    "))))
(global-set-key (kbd "TAB") (lambda () (interactive) (insert "    ")))

;; Tab Bar
(map! :leader
      :desc "Tab bar toggle" "t s" 'tab-bar-mode)
(map! :leader
      :desc "Tab new" "t n" 'tab-bar-new-tab)
(map! :leader
      :desc "Tab close" "t k" 'tab-bar-close-tab)
(map! :leader
      :desc "Tab next" "t <right>" 'tab-bar-switch-to-next-tab)
(map! :leader
      :desc "Tab prev" "t <left>" 'tab-bar-switch-to-prev-tab)

;; Treemacs
(map! :leader
      :desc "Open treemacs" "o o" 'treemacs)

;; Commands
(defun my/uv-run-current-file ()
  "Run `uv run` on the current buffer's file."
  (interactive)
  (let ((file buffer-file-name))
    (unless file
      (user-error "Current buffer is not visiting a file"))
    (compile (format "uv run %s" (shell-quote-argument file)))))

(defun my/uv-run-current-file-with-arg (arg)
  "Prompt for ARG, then run `uv run` on the current file with ARG."
  (interactive (list (read-string "Argument(s) for uv run: ")))
  (let ((file buffer-file-name))
    (unless file
      (user-error "Current buffer is not visiting a file"))
    (compile (format "uv run %s %s"
                     (shell-quote-argument file)
                     arg))))
;; Keybindings only in python buffers
(after! python
  (map! :map python-mode-map
        :leader
        (:prefix ("r" . "run")
         :desc "uv run current file" "r" #'my/uv-run-current-file
         :desc "uv run current file with arg" "a" #'my/uv-run-current-file-with-arg)))

(after! company
  (setq company-idle-delay 0.1)      ;; Show completions instantly as you type
  (setq company-minimum-prefix-length 1)
  (setq company-backends '((company-capf company-files))))

(after! company
  ;; Make TAB confirm selection
  (define-key company-active-map (kbd "TAB") #'company-complete-selection)
  (define-key company-active-map (kbd "<tab>") #'company-complete-selection)

  ;; Make RET insert newline (not accept selection)
  (define-key company-active-map (kbd "RET") nil)
  (define-key company-active-map (kbd "<return>") nil)

  ;; Allow navigation with up/down arrows (usually works by default)
  (define-key company-active-map (kbd "C-j") #'company-select-next)
  (define-key company-active-map (kbd "C-k") #'company-select-previous))

;; Disable lsp documentation
(setq lsp-ui-doc-enable nil lsp-ui-doc-show-with-cursor nil lsp-ui-doc-show-with-mouse nil lsp-eldoc-enable-hover nil lsp-signature-auto-activate nil)
(after! corfu
  (setq corfu-auto nil))

;; First, ensure PATH includes ~/.local/bin
(setenv "PATH"
        (concat (expand-file-name "~/.local/bin")
                ":" (getenv "PATH")))

;; Also adjust exec-path
(add-to-list 'exec-path (expand-file-name "~/.local/bin"))

(map! :leader
      :desc "Aider Menu" "z s" #'aider-run-aider)
(map! :leader
      :desc "Aider Transient Menu" "z a" #'aider-transient-menu)

(setq org-directory "~/Notes/Org/")

(custom-theme-set-faces!
;; 'doom-one
'doom-rose-pine
'(org-level-1 :inherit outline-1 :height 1.5)
'(org-level-2 :inherit outline-2 :height 1.4)
'(org-level-3 :inherit outline-3 :height 1.3)
'(org-level-4 :inherit outline-2 :height 1.2)
'(org-level-5 :inherit outline-5 :height 1.1)
'(org-level-6 :inherit outline-6 :height 1.0)
'(org-level-7 :inherit outline-7 :height 1.0)
'(org-level-8 :inherit outline-8 :height 1.0))
;; '(org-document-title :height 1.6 :bold nil :underline nil))

(setq org-modern-table-vertical t)
(setq org-modern-table t)

(map! :leader
      :desc "Open todo.org"
      "o o" (lambda () (interactive) (find-file "~/Org/index.org")))

;; ~/.doom.d/config.el

(defun my/doom-dashboard-ascii-banner ()
  (let ((banner '(
    "███▄▄▄▄    ▄██████▄   ▄█    █▄     ▄████████    ▄████████  ▄████████    ▄█    █▄   "
    "███▀▀▀██▄ ███    ███ ███    ███   ███    ███   ███    ███ ███    ███   ███    ███  "
    "███   ███ ███    ███ ███    ███   ███    ███   ███    ███ ███    █▀    ███    ███  "
    "███   ███ ███    ███ ███    ███   ███    ███  ▄███▄▄▄▄██▀ ███         ▄███▄▄▄▄███▄▄"
    "███   ███ ███    ███ ███    ███ ▀███████████ ▀▀███▀▀▀▀▀   ███        ▀▀███▀▀▀▀███▀ "
    "███   ███ ███    ███ ███    ███   ███    ███ ▀███████████ ███    █▄    ███    ███  "
    "███   ███ ███    ███ ███    ███   ███    ███   ███    ███ ███    ███   ███    ███  "
    " ▀█   █▀   ▀██████▀   ▀██████▀    ███    █▀    ███    ███ ████████▀    ███    █▀   "
    "                                               ███    ███                          "
)))
    (dolist (line banner)
      (insert (propertize line 'face 'doom-dashboard-banner) "\n"))))

;; ensure Doom uses it (works whether you start GUI or terminal;
;; the ASCII will only be visible in terminal frames)
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-banner)
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu) ; removes menu
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-footer)    ; removes footer
(add-hook '+doom-dashboard-functions #'my/doom-dashboard-ascii-banner)
