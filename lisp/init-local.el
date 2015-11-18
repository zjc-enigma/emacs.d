;; my customize file
(add-to-list 'load-path "~/Git/emacs.d/libs/ESS/lisp")
(load "ess-site")

;;(add-to-list 'load-path "~/Git/emacs.d/libs/el-get")
;;(load "el-get")

;;(add-to-list 'el-get-recipe-path "~/Git/emacs.d/libs/el-get/recipes")
;;(el-get 'sync)

(add-hook 'org-mode-hook (lambda () (setq truncate-lines nil)))
(set-face-attribute 'default nil
                    :family "Source Code Pro" :height 221 :weight 'ultra-light)

;; (add-to-list 'load-path "~/Git/o-blog/lisp")
;; (load "o-blog")

;;(require 'cl-macs)

(require 'linum)
(global-linum-mode 1)


(add-to-list 'load-path "~/Git/emacs.d/libs/tramp/lisp/")
(require 'tramp)
(setq tramp-default-method "ssh")
(setq tramp-default-user "root"
      tramp-default-host "182.92.235.126")



(blink-cursor-mode (- (*) (*) (*)))
(setq desktop-restore-frames nil)
(desktop-save-mode 1)

;;(setq load-path (cons "~/Git/emacs.d/libs/org2blog/" load-path))
;;(load "org2blog-autoloads")

;;(load "xml-rpc")


;; (setq org2blog/wp-blog-alist
;;       '(("wordpress"
;;          :url "http://enigmaspace.org/xmlrpc.php"
;;          :username "infinite"
;;          :default-title "Hello World"
;;          :default-categories ("org2blog" "emacs")
;;          :tags-as-categories nil)
;;         ("my-blog"
;;          :url "http://enigmaspace.org/xmlrpc.php"
;;          :username "infinite")))

(setq process-coding-system-alist '(("R.*" . utf-8)))

(global-set-key (kbd "M-i")  'split-window-horizontally)
(global-set-key (kbd "M-o")  'next-multiframe-window)
(global-set-key (kbd "C-o")  'previous-multiframe-window)
(global-set-key (kbd "C-x g")  'goto-line)
(global-set-key (kbd "M-m") 'delete-other-windows)

(global-set-key (kbd "M-h")  "->")
(global-set-key (kbd "M-u")  "<-")

(setq indent-tabs-mode nil)
(setq tab-width 4)
(setq tab-stop-list ())
(loop for x downfrom 40 to 1 do
      (setq tab-stop-list (cons (* x 4) tab-stop-list)))

(defconst my-c-style
  '((c-tab-always-indent        . t)
    (c-comment-only-line-offset . 4)
    (c-hanging-braces-alist     . ((substatement-open after)
                                   (brace-list-open)))
    (c-hanging-colons-alist     . ((member-init-intro before)
                                   (inher-intro)
                                   (case-label after)
                                   (label after)
                                   (access-label after)))
    (c-cleanup-list             . (scope-operator
                                   empty-defun-braces
                                   defun-close-semi))
    (c-offsets-alist            . ((arglist-close . c-lineup-arglist)
                                   (substatement-open . 0)
                                   (case-label        . 4)
                                   (block-open        . 0)
                                   (knr-argdecl-intro . -)))
    (c-echo-syntactic-information-p . t))
  "My C Programming Style")

;; offset customizations not in my-c-style
(setq c-offsets-alist '((member-init-intro . ++)))

;; Customizations for all modes in CC Mode.
(defun my-c-mode-common-hook ()
  ;; add my personal style and set it for the current buffer
  (c-add-style "PERSONAL" my-c-style t)
  ;; other customizations
  (setq tab-width 4
        ;; this will make sure spaces are used instead of tabs
        indent-tabs-mode nil)
  ;; we like auto-newline and hungry-delete
  (c-toggle-auto-hungry-state 1))

(add-hook 'c-mode-common-hook 'my-c-mode-common-hook)
(load-file "/Users/Patrick/.emacs.d/site-lisp/piglatin-mode/piglatin.el")

(provide 'init-local)
