;;; fullframe.el --- Generalized automatic execution in a single frame

;; Copyright (C) 2013 Tom Regner

;; Author: Tom Regner <tom@goochesa.de>
;; Maintainer: Tom Regner <tom@goochesa.de>
;; Version: 20140208.805
;; X-Original-Version: 0.0.5
;; Keywords: fullscreen

;;  This file is NOT part of GNU Emacs

;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Generalized automatic execution in a single frame
;;
;; This is a library that package developers can use to provide user
;; friendly single window per frame execution of buffer exposing
;; commands, as well as to use in personal Emacs configurations to attain
;; the same goal for packages that don't use =fullframe= or the likes of
;; it themself.
;;
;;  Example: Setup =magit-status= to open in one window in the current
;;  frame when called
;; Example:
;; - Open magit-status in a single window in fullscreen
;;   (require 'fullframe)
;;   (fullframe magit-status magit-mode-quit-window nil)
;;
;;; Code:

(require 'cl-lib)

;; customization
;; - none

;; variables
(defvar fullframe/previous-window-configuration nil
  "The window configuration to restore.")
(make-variable-buffer-local 'fullframe/previous-window-configuration)

;; internal functions

(defun fullframe/maybe-restore-configuration (config)
  "Restore CONFIG if non-nil."
  (when config
    (condition-case nil
        (set-window-configuration config)
      (error (message "Failed to restore all windows.")))))

;; API
;;;###autoload
(defmacro fullframe (command-on command-off &optional kill-on-coff ignored)
  "Save window/frame state when executing COMMAND-ON.

Advises COMMAND-ON so that the buffer it displays will appear in
a full-frame window.  The previous window configuration will be
restored when COMMAND-OFF is executed in that buffer.  If
KILL-ON-COFF is non-nil, then the buffer will also be killed
after COMMAND-OFF has completed.

IGNORED is there for backcompatibillitys sake -- ignore it."
  (when (keywordp kill-on-coff)
    (error "The register parameter for fullframe has been removed"))
  (let* ((window-config (cl-gensym "fullframe-config-"))
         (window-config-post (cl-gensym "fullframe-config-post-"))
         (buf (cl-gensym "fullframe-buf-")))
    `(progn
       (defadvice ,command-on (around fullframe activate)
         (let ((,window-config (current-window-configuration)))
           ad-do-it
           (let ((,window-config-post (current-window-configuration)))
             (delete-other-windows)
             (unless (equal ,window-config-post (current-window-configuration))
               (setq fullframe/previous-window-configuration ,window-config)))))
       (defadvice ,command-off (around fullframe activate)
         (let ((,window-config fullframe/previous-window-configuration)
               (,buf (current-buffer)))
           (prog1
               ad-do-it
             (fullframe/maybe-restore-configuration ,window-config)
             ,(when kill-on-coff `(kill-buffer ,buf))))))))

;; interactive functions
;; - none

(provide 'fullframe)
;;; fullframe.el ends here
