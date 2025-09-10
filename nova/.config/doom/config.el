(setq doom-font (font-spec :family "JetBrains Mono NL Nerd Font" :size 15))

(setq doom-theme 'doom-tokyo-night)

(setq display-line-numbers-type t)

(setq confirm-kill-emacs nil)

(setq org-directory "~/Notes/Org/")

(custom-theme-set-faces!
'doom-one
'(org-level-1 :inherit outline-1 :height 1.5)
'(org-level-2 :inherit outline-2 :height 1.4)
'(org-level-3 :inherit outline-3 :height 1.3)
'(org-level-4 :inherit outline-2 :height 1.2)
'(org-level-5 :inherit outline-5 :height 1.1)
'(org-level-6 :inherit outline-6 :height 1.0)
'(org-level-7 :inherit outline-7 :height 1.0)
'(org-level-8 :inherit outline-8 :height 1.0)
'(org-document-title :height 1.6 :bold nil :underline nil))

(setq org-modern-table-vertical t)
(setq org-modern-table t)

(map! :leader
      :desc "Open todo.org"
      "o o" (lambda () (interactive) (find-file "~/Notes/Org/index.org")))

(map! :leader
      :desc "Kill buffer" "q w" #'kill-current-buffer)

;; Unset existing bindings
(global-unset-key (kbd "M-<left>"))
(global-unset-key (kbd "M-<right>"))
;; Set M-<left> and M-<right> to switch buffers
(global-set-key (kbd "M-<left>") #'previous-buffer)
(global-set-key (kbd "M-<right>") #'next-buffer)

;; Force TAB to insert two spaces in programming modes
(after! prog-mode
  (map! :map prog-mode-map
        :i [tab] (lambda () (interactive) (insert "    ")))); Insert two spaces instead of indent

;; Force TAB to insert two spaces in all modes
(global-set-key (kbd "TAB") (lambda () (interactive) (insert "    ")))  ;; Insert two spaces

(setq lsp-ui-doc-enable nil lsp-ui-doc-show-with-cursor nil lsp-ui-doc-show-with-mouse nil lsp-eldoc-enable-hover nil lsp-signature-auto-activate nil)

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
