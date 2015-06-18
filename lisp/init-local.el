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



(require 'linum)
(global-linum-mode 1)


(blink-cursor-mode (- (*) (*) (*)))
(setq desktop-restore-frames nil)
(desktop-save-mode 1)

(setq process-coding-system-alist '(("R.*" . utf-8)))

(global-set-key (kbd "M-i")  'split-window-horizontally)
(global-set-key (kbd "M-o")  'next-multiframe-window)
(global-set-key (kbd "C-o")  'previous-multiframe-window)
(global-set-key (kbd "C-x g")  'goto-line)
(global-set-key (kbd "M-m") 'delete-other-windows)

(global-set-key (kbd "M-h")  "->")
(global-set-key (kbd "M-u")  "<-")
;;(global-set-key (kbd "C-m") 'set-mark-command)

(define-key global-map (kbd "M-n") 'next-buffer)
(define-key global-map (kbd "M-p") 'previous-buffer)
                                                        

(provide 'init-local)
