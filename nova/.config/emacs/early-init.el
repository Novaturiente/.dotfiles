;;; early-init.el --- runs before the package system and the first frame -*- lexical-binding: t; -*-

;; Startup speed: no garbage collection and no file-handler regex matching
;; while init loads. Both are restored once startup is done.
(setq gc-cons-threshold most-positive-fixnum)
(defvar nova--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  file-name-handler-alist nova--file-name-handler-alist)))

;; Set here rather than toggled in init.el, so the bars are never drawn at all.
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil
      inhibit-startup-screen t
      frame-inhibit-implied-resize t)

;; Font: the terminal's. The first uncommented font-family and font-size in
;; Ghostty's config are read on every start, so changing the terminal font
;; changes this too. init.el reuses the family for icons.
(defvar nova-font-family "monospace")
(let ((size "13"))
  (with-temp-buffer
    (ignore-errors (insert-file-contents "~/.config/ghostty/config")) ; absent on a machine without Ghostty
    (when (re-search-forward "^font-family *= *\"?\\([^\"\n]+?\\)\"? *$" nil t)
      (setq nova-font-family (match-string 1)))
    (goto-char (point-min))
    (when (re-search-forward "^font-size *= *\\([0-9.]+\\)" nil t)
      (setq size (match-string 1))))
  (push (cons 'font (format "%s-%s" nova-font-family size)) default-frame-alist))

;; ~/.config/emacs is a stow symlink into the dotfiles repo; keep generated
;; files out of it.
(defconst nova-cache (expand-file-name "~/.cache/emacs/"))
(startup-redirect-eln-cache (expand-file-name "eln-cache/" nova-cache))

;; Packages are activated right after this file, so their location must be set
;; here. Quickstart activates everything from one cached file, and packages are
;; native-compiled at install time instead of lazily in the background.
(setq package-user-dir (expand-file-name "elpa" nova-cache)
      package-quickstart t
      package-quickstart-file (expand-file-name "package-quickstart.el" nova-cache)
      package-native-compile t)
