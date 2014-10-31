;; my customize file
(add-to-list 'load-path "~/Git/emacs.d/lib/ESS/lisp")
(load "ess-site")

(add-to-list 'load-path "~/Git/emacs.d/lib/el-get")
(load "el-get")
(add-to-list 'el-get-recipe-path "~/Git/emacs.d/lib/el-get/recipes")
(el-get 'sync)

(add-hook 'org-mode-hook (lambda () (setq truncate-lines nil)))
(set-face-attribute 'default nil
                    :family "Source Code Pro" :height 221 :weight 'ultra-light)

;; (add-to-list 'load-path "~/Git/o-blog/lisp")
;; (load "o-blog")

;;(require 'cl-macs)

(require 'linum)
(global-linum-mode 1)
(provide 'init-local)

(blink-cursor-mode (- (*) (*) (*)))
(setq desktop-restore-frames nil)
(desktop-save-mode 1)

(setq load-path (cons "~/Git/emacs.d/lib/org2blog/" load-path))
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
