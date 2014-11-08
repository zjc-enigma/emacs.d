;; my customize file
(add-to-list 'load-path "~/Git/emacs.d/libs/ESS/lisp")
(load "ess-site")

(add-to-list 'load-path "~/Git/emacs.d/libs/el-get")
(load "el-get")
(add-to-list 'el-get-recipe-path "~/Git/emacs.d/libs/el-get/recipes")
(el-get 'sync)

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

(setq load-path (cons "~/Git/emacs.d/libs/org2blog/" load-path))
(load "org2blog-autoloads")
(load "xml-rpc")


(setq org2blog/wp-blog-alist
      '(("wordpress"
         :url "http://enigmaspace.org/xmlrpc.php"
         :username "infinite"
         :default-title "Hello World"
         :default-categories ("org2blog" "emacs")
         :tags-as-categories nil)
        ("my-blog"
         :url "http://enigmaspace.org/xmlrpc.php"
         :username "infinite")))

(setq process-coding-system-alist '(("R.*" . utf-8)))

(global-set-key (kbd "M-i")  'split-window-horizontally)
(global-set-key (kbd "M-o")  'next-multiframe-window)
(global-set-key (kbd "C-o")  'previous-multiframe-window)
(global-set-key (kbd "C-x g")  'goto-line)
(global-set-key (kbd "M-m") 'delete-other-windows)

(global-set-key (kbd "M-h")  "->")
(global-set-key (kbd "M-u")  "<-")

(provide 'init-local)
