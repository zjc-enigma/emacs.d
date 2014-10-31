;;; slime-tests.el --- Automated tests for slime.el
;;
;;;; License
;;     Copyright (C) 2003  Eric Marsden, Luke Gorrie, Helmut Eller
;;     Copyright (C) 2004,2005,2006  Luke Gorrie, Helmut Eller
;;     Copyright (C) 2007,2008,2009  Helmut Eller, Tobias C. Rittweiler
;;     Copyright (C) 2013
;;
;;     For a detailed list of contributors, see the manual.
;;
;;     This program is free software; you can redistribute it and/or
;;     modify it under the terms of the GNU General Public License as
;;     published by the Free Software Foundation; either version 2 of
;;     the License, or (at your option) any later version.
;;
;;     This program is distributed in the hope that it will be useful,
;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;;     GNU General Public License for more details.
;;
;;     You should have received a copy of the GNU General Public
;;     License along with this program; if not, write to the Free
;;     Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;;     MA 02111-1307, USA.


;;;; Tests
(require 'slime)
(require 'ert nil t)
(require 'ert "lib/ert" t) ;; look for bundled version for Emacs 23
(require 'cl-lib)

(defun slime-shuffle-list (list)
  (let* ((len (length list))
         (taken (make-vector len nil))
         (result (make-vector len nil)))
    (dolist (e list)
      (while (let ((i (random len)))
               (cond ((aref taken i))
                     (t (aset taken i t)
                        (aset result i e)
                        nil)))))
    (append result '())))

(defun slime-batch-test (&optional test-name randomize)
  "Run the test suite in batch-mode.
Exits Emacs when finished. The exit code is the number of failed tests."
  (interactive)
  (let ((ert-debug-on-error nil)
        (timeout 30)
        (slime-background-message-function #'ignore))
    (slime)
    ;; Block until we are up and running.
    (lexical-let (timed-out)
      (run-with-timer timeout nil
                      (lambda () (setq timed-out t)))
      (while (not (slime-connected-p))
        (sit-for 1)
        (when timed-out
          (when noninteractive
            (kill-emacs 252)))))
    (slime-sync-to-top-level 5)
    (let* ((selector (if randomize
                         `(member ,@(slime-shuffle-list
                                     (ert-select-tests (or test-name t) t)))
                       (or test-name t)))
           (ert-fun (if noninteractive
                        'ert-run-tests-batch
                      'ert)))
      (let ((stats (funcall ert-fun selector)))
        (if noninteractive
            (kill-emacs (ert-stats-completed-unexpected stats)))))))

(defun slime-skip-test (message)
  ;; ERT for Emacs 23 and earlier doesn't have `ert-skip'
  (if (fboundp 'ert-skip)
      (ert-skip message)
    (message (concat "SKIPPING: " message))
    (ert-pass)))

(eval-and-compile
  (defun slime-tests-auto-tags ()
    (append '(slime)
            (let ((file-name (or load-file-name
                                 byte-compile-current-file)))
              (if (and file-name
                       (string-match "contrib/test/slime-\\(.*\\)\.elc?$" file-name))
                  (list 'contrib (intern (match-string 1 file-name)))
                '(core)))))
  
  (defmacro define-slime-ert-test (name &rest args)
    "Like `ert-deftest', but set tags automatically.
Also don't error if `ert.el' is missing."
    (if (not (featurep 'ert))
        (warn "No ert.el found: not defining test %s"
              name)
      (let* ((docstring (and (stringp (second args))
                             (second args)))
             (args (if docstring
                       (cddr args)
                     (cdr args)))
             (tags (slime-tests-auto-tags)))
        `(ert-deftest ,name () ,(or docstring "No docstring for this test.")
           :tags ',tags
           ,@args))))

  (defun slime-test-ert-test-for (name input i doc body fails-for style fname)
    `(define-slime-ert-test
       ,(intern (format "%s-%d" name i)) ()
       ,(format "For input %s, %s" (truncate-string-to-width
                                    (format "%s" input)
                                    15 nil nil 'ellipsis)
                (replace-regexp-in-string "^.??\\(\\w+\\)"
                                          (lambda (s) (downcase s))
                                          doc
                                          t))
       ,@(if fails-for
             `(:expected-result '(satisfies
                                  (lambda (result)
                                    (ert-test-result-type-p
                                     result
                                     (if (member
                                          (slime-lisp-implementation-name)
                                          ',fails-for)
                                         :failed
                                       :passed))))))

       ,@(when style
           `((let ((style (slime-communication-style)))
               (when (not (member style ',style))
                 (slime-skip-test (format "test not applicable for style %s"
                                          style))))))
       (apply #',fname ',input))))

(defmacro def-slime-test (name args doc inputs &rest body)
  "Define a test case.
NAME    ::= SYMBOL | (SYMBOL OPTION*) is a symbol naming the test.
OPTION  ::= (:fails-for IMPLEMENTATION*) | (:style COMMUNICATION-STYLE*)
ARGS is a lambda-list.
DOC is a docstring.
INPUTS is a list of argument lists, each tested separately.
BODY is the test case. The body can use `slime-check' to test
conditions (assertions)."
  (declare (debug (&define name sexp sexp sexp &rest def-form)))
  (if (not (featurep 'ert))
      (warn "No ert.el found: not defining test %s"
            name)
    `(progn
     ,@(cl-destructuring-bind (name &rest options)
           (if (listp name) name (list name))
         (let ((fname (intern (format "slime-test-%s" name))))
           (cons `(defun ,fname ,args
                    (slime-sync-to-top-level 0.3)
                    ,@body
                    (slime-sync-to-top-level 0.3))
                 (loop for input in (eval inputs)
                       for i from 1
                       with fails-for = (cdr (assoc :fails-for options))
                       with style = (cdr (assoc :style options))
                       collect (slime-test-ert-test-for name
                                                        input
                                                        i
                                                        doc
                                                        body
                                                        fails-for
                                                        style
                                                        fname))))))))

(put 'def-slime-test 'lisp-indent-function 4)

(defmacro slime-check (check &rest body)
  `(unless (progn ,@body)
     (ert-fail ,(cl-etypecase check
                  (cons `(concat "Ooops, " ,(cons 'format check)))
                  (string `(concat "Check failed: " ,check))
                  (symbol `(concat "Check failed: " ,(symbol-name check)))))))


;;;;; Test case definitions
;; Clear out old tests.
(setq slime-tests nil)

(defun slime-check-top-level () ;(&optional _test-name)
  (slime-accept-process-output nil 0.001)
  (slime-check "At the top level (no debugging or pending RPCs)"
    (slime-at-top-level-p)))

(defun slime-at-top-level-p ()
  (and (not (sldb-get-default-buffer))
       (null (slime-rex-continuations))))

(defun slime-wait-condition (name predicate timeout)
  (let ((end (time-add (current-time) (seconds-to-time timeout))))
    (while (not (funcall predicate))
      (let ((now (current-time)))
        (message "waiting for condition: %s [%s.%06d]" name
                 (format-time-string "%H:%M:%S" now) (third now)))
      (cond ((time-less-p end (current-time))
             (error "Timeout waiting for condition: %S" name))
            (t
             ;; XXX if a process-filter enters a recursive-edit, we
             ;; hang forever
             (slime-accept-process-output nil 0.1))))))

(defun slime-sync-to-top-level (timeout)
  (slime-wait-condition "top-level" #'slime-at-top-level-p timeout))

;; XXX: unused function
(defun slime-check-sldb-level (expected)
  (let ((sldb-level (when-let (sldb (sldb-get-default-buffer))
                      (with-current-buffer sldb
                        sldb-level))))
    (slime-check ("SLDB level (%S) is %S" expected sldb-level)
      (equal expected sldb-level))))

(defun slime-test-expect (_name expected actual &optional test)
  (when (stringp expected) (setq expected (substring-no-properties expected)))
  (when (stringp actual)   (setq actual (substring-no-properties actual)))
  (if test
      (should (funcall test expected actual))
    (should (equal expected actual))))

(defun sldb-level ()
  (when-let (sldb (sldb-get-default-buffer))
    (with-current-buffer sldb
      sldb-level)))

(defun slime-sldb-level= (level)
  (equal level (sldb-level)))

(eval-when-compile
  (defvar slime-test-symbols
  '(("foobar") ("foo@bar") ("@foobar") ("foobar@") ("\\@foobar")
    ("|asdf||foo||bar|")
    ("\\#<Foo@Bar>")
    ("\\(setf\\ car\\)"))))

(defun slime-check-symbol-at-point (prefix symbol suffix)
  ;; We test that `slime-symbol-at-point' works at every
  ;; character of the symbol name.
  (with-temp-buffer
    (lisp-mode)
    (insert prefix)
    (let ((start (point)))
      (insert symbol suffix)
      (dotimes (i (length symbol))
        (goto-char (+ start i))
        (slime-test-expect (format "Check `%s' (at %d)..."
                                   (buffer-string) (point))
                           symbol
                           (slime-symbol-at-point)
                           #'equal)))))



(def-slime-test symbol-at-point.2 (sym)
  "fancy symbol-name _not_ at BOB/EOB"
  slime-test-symbols
  (slime-check-symbol-at-point "(foo " sym " bar)"))

(def-slime-test symbol-at-point.3 (sym)
  "fancy symbol-name with leading ,"
  (remove-if (lambda (s) (eq (aref (car s) 0) ?@)) slime-test-symbols)
  (slime-check-symbol-at-point "," sym ""))

(def-slime-test symbol-at-point.4 (sym)
  "fancy symbol-name with leading ,@"
  slime-test-symbols
  (slime-check-symbol-at-point ",@" sym ""))

(def-slime-test symbol-at-point.5 (sym)
  "fancy symbol-name with leading `"
  slime-test-symbols
  (slime-check-symbol-at-point "`" sym ""))

(def-slime-test symbol-at-point.6 (sym)
  "fancy symbol-name wrapped in ()"
  slime-test-symbols
  (slime-check-symbol-at-point "(" sym ")"))

(def-slime-test symbol-at-point.7 (sym)
  "fancy symbol-name wrapped in #< {DEADBEEF}>"
  slime-test-symbols
  (slime-check-symbol-at-point "#<" sym " {DEADBEEF}>"))

;;(def-slime-test symbol-at-point.8 (sym)
;;  "fancy symbol-name wrapped in #<>"
;;  slime-test-symbols
;;  (slime-check-symbol-at-point "#<" sym ">"))

(def-slime-test symbol-at-point.9 (sym)
  "fancy symbol-name wrapped in #| ... |#"
  slime-test-symbols
  (slime-check-symbol-at-point "#|\n" sym "\n|#"))

(def-slime-test symbol-at-point.10 (sym)
  "fancy symbol-name after #| )))(( |# (1)"
  slime-test-symbols
  (slime-check-symbol-at-point "#| )))(( #|\n" sym ""))

(def-slime-test symbol-at-point.11 (sym)
  "fancy symbol-name after #| )))(( |# (2)"
  slime-test-symbols
  (slime-check-symbol-at-point "#| )))(( #|" sym ""))

(def-slime-test symbol-at-point.12 (sym)
  "fancy symbol-name wrapped in \"...\""
  slime-test-symbols
  (slime-check-symbol-at-point "\"\n" sym "\"\n"))

(def-slime-test symbol-at-point.13 (sym)
  "fancy symbol-name wrapped in \" )))(( \" (1)"
  slime-test-symbols
  (slime-check-symbol-at-point "\" )))(( \"\n" sym ""))

(def-slime-test symbol-at-point.14 (sym)
  "fancy symbol-name wrapped in \" )))(( \" (1)"
  slime-test-symbols
  (slime-check-symbol-at-point "\" )))(( \"" sym ""))

(def-slime-test symbol-at-point.15 (sym)
  "symbol-at-point after #."
  slime-test-symbols
  (slime-check-symbol-at-point "#." sym ""))

(def-slime-test symbol-at-point.16 (sym)
  "symbol-at-point after #+"
  slime-test-symbols
  (slime-check-symbol-at-point "#+" sym ""))


(def-slime-test sexp-at-point.1 (string)
  "symbol-at-point after #'"
  '(("foo")
    ("#:foo")
    ("#'foo")
    ("#'(lambda (x) x)")
    ("()"))
  (with-temp-buffer
    (lisp-mode)
    (insert string)
    (goto-char (point-min))
    (slime-test-expect (format "Check sexp `%s' (at %d)..."
                               (buffer-string) (point))
                       string
                       (slime-sexp-at-point)
                       #'equal)))

(def-slime-test narrowing ()
    "Check that narrowing is properly sustained."
    '()
  (slime-check-top-level)
  (let ((random-buffer-name (symbol-name (cl-gensym)))
        (defun-pos) (tmpbuffer))
    (with-temp-buffer
      (dotimes (i 100) (insert (format ";;; %d. line\n" i)))
      (setq tmpbuffer (current-buffer))
      (setq defun-pos (point))
      (insert (concat "(defun __foo__ (x y)" "\n"
                      "  'nothing)"          "\n"))
      (dotimes (i 100) (insert (format ";;; %d. line\n" (+ 100 i))))
      (slime-check "Checking that newly created buffer is not narrowed."
        (not (slime-buffer-narrowed-p)))

      (goto-char defun-pos)
      (narrow-to-defun)
      (slime-check "Checking that narrowing succeeded."
       (slime-buffer-narrowed-p))

      (slime-with-popup-buffer (random-buffer-name)
        (slime-check ("Checking that we're in Slime's temp buffer `%s'"
                      random-buffer-name)
          (equal (buffer-name (current-buffer)) random-buffer-name)))
      (with-current-buffer random-buffer-name
        ;; Notice that we cannot quit the buffer within the extent
        ;; of slime-with-output-to-temp-buffer.
        (slime-popup-buffer-quit t))
      (slime-check ("Checking that we've got back from `%s'"
                    random-buffer-name)
        (and (eq (current-buffer) tmpbuffer)
             (= (point) defun-pos)))

      (slime-check "Checking that narrowing sustained \
after quitting Slime's temp buffer."
        (slime-buffer-narrowed-p))

      (let ((slime-buffer-package "SWANK")
            (symbol '*buffer-package*))
        (slime-edit-definition (symbol-name symbol))
        (slime-check ("Checking that we've got M-. into swank.lisp. %S" symbol)
          (string= (file-name-nondirectory (buffer-file-name))
                   "swank.lisp"))
        (slime-pop-find-definition-stack)
        (slime-check ("Checking that we've got back.")
          (and (eq (current-buffer) tmpbuffer)
               (= (point) defun-pos)))

        (slime-check "Checking that narrowing sustained after M-,"
          (slime-buffer-narrowed-p)))
      ))
  (slime-check-top-level))

(def-slime-test find-definition
    (name buffer-package snippet)
    "Find the definition of a function or macro in swank.lisp."
    '(("start-server" "SWANK" "(defun start-server ")
      ("swank::start-server" "CL-USER" "(defun start-server ")
      ("swank:start-server" "CL-USER" "(defun start-server ")
      ("swank::connection" "CL-USER" "(defstruct (connection")
      ("swank::*emacs-connection*" "CL-USER" "(defvar \\*emacs-connection\\*")
      )
  (switch-to-buffer "*scratch*")        ; not buffer of definition
  (slime-check-top-level)
  (let ((orig-buffer (current-buffer))
        (orig-pos (point))
        (enable-local-variables nil)    ; don't get stuck on -*- eval: -*-
        (slime-buffer-package buffer-package))
    (slime-edit-definition name)
    ;; Postconditions
    (slime-check ("Definition of `%S' is in swank.lisp." name)
      (string= (file-name-nondirectory (buffer-file-name)) "swank.lisp"))
    (slime-check "Definition now at point." (looking-at snippet))
    (slime-pop-find-definition-stack)
    (slime-check "Returning from definition restores original buffer/position."
      (and (eq orig-buffer (current-buffer))
           (= orig-pos (point)))))
    (slime-check-top-level))

(def-slime-test (find-definition.2 (:fails-for "allegro" "lispworks"))
    (buffer-content buffer-package snippet)
    "Check that we're able to find definitions even when
confronted with nasty #.-fu."
    '(("#.(prog1 nil (defvar *foobar* 42))

       (defun .foo. (x)
         (+ x #.*foobar*))

       #.(prog1 nil (makunbound '*foobar*))
       "
       "SWANK"
       "[ \t]*(defun .foo. "
       ))
  (let ((slime-buffer-package buffer-package))
    (with-temp-buffer
      (insert buffer-content)
      (slime-check-top-level)
      (slime-eval
       `(swank:compile-string-for-emacs
         ,buffer-content
         ,(buffer-name)
         '((:position 0) (:line 1 1))
         ,nil
         ,nil))
      (let ((bufname (buffer-name)))
        (slime-edit-definition ".foo.")
        (slime-check ("Definition of `.foo.' is in buffer `%s'." bufname)
          (string= (buffer-name) bufname))
        (slime-check "Definition now at point." (looking-at snippet)))
      )))

(def-slime-test (find-definition.3
                 (:fails-for "abcl" "allegro" "clisp" "lispworks" "sbcl"
                             "ecl"))
    (name source regexp)
    "Extra tests for defstruct."
    '(("swank::foo-struct"
       "(progn
  (defun foo-fun ())
  (defstruct (foo-struct (:constructor nil) (:predicate nil)))
)"
       "(defstruct (foo-struct"))
  (switch-to-buffer "*scratch*")
    (with-temp-buffer
      (insert source)
      (let ((slime-buffer-package "SWANK"))
        (slime-eval
         `(swank:compile-string-for-emacs
           ,source
           ,(buffer-name)
           '((:position 0) (:line 1 1))
           ,nil
           ,nil)))
      (let ((temp-buffer (current-buffer)))
        (with-current-buffer "*scratch*"
          (slime-edit-definition name)
          (slime-check ("Definition of %S is in buffer `%s'."
                        name temp-buffer)
            (eq (current-buffer) temp-buffer))
          (slime-check "Definition now at point." (looking-at regexp)))
      )))

(def-slime-test complete-symbol
    (prefix expected-completions)
    "Find the completions of a symbol-name prefix."
    '(("cl:compile" (("cl:compile" "cl:compile-file" "cl:compile-file-pathname"
                      "cl:compiled-function" "cl:compiled-function-p"
                      "cl:compiler-macro" "cl:compiler-macro-function")
                     "cl:compile"))
      ("cl:foobar" (nil ""))
      ("swank::compile-file" (("swank::compile-file"
                               "swank::compile-file-for-emacs"
                               "swank::compile-file-if-needed"
                               "swank::compile-file-output"
                               "swank::compile-file-pathname")
                              "swank::compile-file"))
      ("cl:m-v-l" (nil "")))
  (let ((completions (slime-simple-completions prefix)))
    (slime-test-expect "Completion set" expected-completions completions)))

(def-slime-test arglist
    ;; N.B. Allegro apparently doesn't return the default values of
    ;; optional parameters. Thus the regexp in the start-server
    ;; expected value. In a perfect world we'd find a way to smooth
    ;; over this difference between implementations--perhaps by
    ;; convincing Franz to provide a function that does what we want.
    (function-name expected-arglist)
    "Lookup the argument list for FUNCTION-NAME.
Confirm that EXPECTED-ARGLIST is displayed."
    '(("swank::operator-arglist" "(swank::operator-arglist name package)")
      ("swank::compute-backtrace" "(swank::compute-backtrace start end)")
      ("swank::emacs-connected" "(swank::emacs-connected)")
      ("swank::compile-string-for-emacs"
       "(swank::compile-string-for-emacs \
string buffer position filename policy)")
      ("swank::connection.socket-io"
       "(swank::connection.socket-io \
\\(struct\\(ure\\)?\\|object\\|instance\\|x\\|connection\\))")
      ("cl:lisp-implementation-type" "(cl:lisp-implementation-type)")
      ("cl:class-name"
       "(cl:class-name \\(class\\|object\\|instance\\|structure\\))"))
  (let ((arglist (slime-eval `(swank:operator-arglist ,function-name
                                                      "swank"))))
    (slime-test-expect "Argument list is as expected"
                       expected-arglist (and arglist (downcase arglist))
                       (lambda (pattern arglist)
                         (and arglist (string-match pattern arglist))))))

(def-slime-test (compile-defun (:fails-for "allegro" "lispworks" "clisp"
                                           "ccl"))
    (program subform)
    "Compile PROGRAM containing errors.
Confirm that SUBFORM is correctly located."
    '(("(defun cl-user::foo () (cl-user::bar))" (cl-user::bar))
      ("(defun cl-user::foo ()
          #\\space
          ;;Sdf
          (cl-user::bar))"
       (cl-user::bar))
      ("(defun cl-user::foo ()
             #+(or)skipped
             #| #||#
                #||# |#
             (cl-user::bar))"
       (cl-user::bar))
      ("(defun cl-user::foo ()
           (list `(1 ,(random 10) 2 ,@(random 10) 3 ,(cl-user::bar))))"
       (cl-user::bar))
      ("(defun cl-user::foo ()
          \"\\\" bla bla \\\"\"
          (cl-user::bar))"
       (cl-user::bar))
      ("(defun cl-user::foo ()
          #.*log-events*
          (cl-user::bar))"
       (cl-user::bar))
      ("#.'(defun x () (/ 1 0))
        (defun foo ()
           (cl-user::bar))

        "
       (cl-user::bar))
      ("(defun foo ()
          #+#.'(:and) (/ 1 0))"
       (/ 1 0))
      )
  (slime-check-top-level)
  (with-temp-buffer
    (lisp-mode)
    (insert program)
    (let ((font-lock-verbose nil))
      (setq slime-buffer-package ":swank")
      (slime-compile-string (buffer-string) 1)
      (setq slime-buffer-package ":cl-user")
      (slime-sync-to-top-level 5)
      (goto-char (point-max))
      (slime-previous-note)
      (slime-check error-location-correct
        (equal (read (current-buffer)) subform))))
  (slime-check-top-level))

(def-slime-test (compile-file (:fails-for "allegro" "lispworks" "clisp"))
    (string)
    "Insert STRING in a file, and compile it."
    `((,(pp-to-string '(defun foo () nil))))
  (let ((filename "/tmp/slime-tmp-file.lisp"))
    (with-temp-file filename
      (insert string))
    (let ((cell (cons nil nil)))
      (slime-eval-async
       `(swank:compile-file-for-emacs ,filename nil)
       (slime-rcurry (lambda (result cell)
                       (setcar cell t)
                       (setcdr cell result))
                     cell))
      (slime-wait-condition "Compilation finished" (lambda () (car cell))
                            0.5)
      (let ((result (cdr cell)))
        (slime-check "Compilation successfull"
          (eq (slime-compilation-result.successp result) t))))))

(def-slime-test utf-8-source
    (input output)
    "Source code containing utf-8 should work"
    (list (let*  ((bytes "\343\201\212\343\201\257\343\202\210\343\201\206")
                  ;;(encode-coding-string (string #x304a #x306f #x3088 #x3046)
                  ;;                      'utf-8)
                  (string (decode-coding-string bytes 'utf-8-unix)))
            (assert (equal bytes (encode-coding-string string 'utf-8-unix)))
            (list (concat "(defun cl-user::foo () \"" string "\")")
                  string)))
  (slime-eval `(cl:eval (cl:read-from-string ,input)))
  (slime-test-expect "Eval result correct"
                     output (slime-eval '(cl-user::foo)))
  (let ((cell (cons nil nil)))
    (let ((hook (slime-curry (lambda (cell &rest _) (setcar cell t)) cell)))
      (add-hook 'slime-compilation-finished-hook hook)
      (unwind-protect
          (progn
            (slime-compile-string input 0)
            (slime-wait-condition "Compilation finished"
                                  (lambda () (car cell))
                                  0.5)
            (slime-test-expect "Compile-string result correct"
                               output (slime-eval '(cl-user::foo))))
        (remove-hook 'slime-compilation-finished-hook hook))
      (let ((filename "/tmp/slime-tmp-file.lisp"))
        (setcar cell nil)
        (add-hook 'slime-compilation-finished-hook hook)
        (unwind-protect
            (with-temp-buffer
              (when (fboundp 'set-buffer-multibyte)
                (set-buffer-multibyte t))
              (setq buffer-file-coding-system 'utf-8-unix)
              (setq buffer-file-name filename)
              (insert ";; -*- coding: utf-8-unix -*- \n")
              (insert input)
              (let ((coding-system-for-write 'utf-8-unix))
                (write-region nil nil filename nil t))
              (let ((slime-load-failed-fasl 'always))
                (slime-compile-and-load-file)
                (slime-wait-condition "Compilation finished"
                                      (lambda () (car cell))
                                      0.5))
              (slime-test-expect "Compile-file result correct"
                                 output (slime-eval '(cl-user::foo))))
          (remove-hook 'slime-compilation-finished-hook hook)
          (ignore-errors (delete-file filename)))))))

(def-slime-test async-eval-debugging (depth)
  "Test recursive debugging of asynchronous evaluation requests."
  '((1) (2) (3))
  (lexical-let ((depth depth)
                (debug-hook-max-depth 0))
    (let ((debug-hook
           (lambda ()
             (with-current-buffer (sldb-get-default-buffer)
               (when (> sldb-level debug-hook-max-depth)
                 (setq debug-hook-max-depth sldb-level)
                 (if (= sldb-level depth)
                     ;; We're at maximum recursion - time to unwind
                     (sldb-quit)
                   ;; Going down - enter another recursive debug
                   ;; Recursively debug.
                   (slime-eval-async '(error))))))))
      (let ((sldb-hook (cons debug-hook sldb-hook)))
        (slime-eval-async '(error))
        (slime-sync-to-top-level 5)
        (slime-check ("Maximum depth reached (%S) is %S."
                      debug-hook-max-depth depth)
          (= debug-hook-max-depth depth))))))

(def-slime-test unwind-to-previous-sldb-level (level2 level1)
  "Test recursive debugging and returning to lower SLDB levels."
  '((2 1) (4 2))
  (slime-check-top-level)
  (lexical-let ((level2 level2)
                (level1 level1)
                (state 'enter)
                (max-depth 0))
    (let ((debug-hook
           (lambda ()
             (with-current-buffer (sldb-get-default-buffer)
               (setq max-depth (max sldb-level max-depth))
               (ecase state
                 (enter
                  (cond ((= sldb-level level2)
                         (setq state 'leave)
                         (sldb-invoke-restart (sldb-first-abort-restart)))
                        (t
                         (slime-eval-async `(cl:aref cl:nil ,sldb-level)))))
                 (leave
                  (cond ((= sldb-level level1)
                         (setq state 'ok)
                         (sldb-quit))
                        (t
                         (sldb-invoke-restart (sldb-first-abort-restart))
                         ))))))))
      (let ((sldb-hook (cons debug-hook sldb-hook)))
        (slime-eval-async `(cl:aref cl:nil 0))
        (slime-sync-to-top-level 15)
        (slime-check-top-level)
        (slime-check ("Maximum depth reached (%S) is %S." max-depth level2)
          (= max-depth level2))
        (slime-check ("Final state reached.")
          (eq state 'ok))))))

(defun sldb-first-abort-restart ()
  (let ((case-fold-search t))
    (cl-position-if (lambda (x) (string-match "abort" (car x))) sldb-restarts)))

(def-slime-test loop-interrupt-quit
    ()
    "Test interrupting a loop."
    '(())
  (slime-check-top-level)
  (slime-eval-async '(cl:loop) (lambda (_) ) "CL-USER")
  (slime-accept-process-output nil 1)
  (slime-check "In eval state." (slime-busy-p))
  (slime-interrupt)
  (slime-wait-condition "First interrupt" (lambda () (slime-sldb-level= 1)) 5)
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-quit))
  (slime-sync-to-top-level 5)
  (slime-check-top-level))

(def-slime-test loop-interrupt-continue-interrupt-quit
    ()
    "Test interrupting a previously interrupted but continued loop."
    '(())
  (slime-check-top-level)
  (slime-eval-async '(cl:loop) (lambda (_) ) "CL-USER")
  (sleep-for 1)
  (slime-wait-condition "running" #'slime-busy-p 5)
  (slime-interrupt)
  (slime-wait-condition "First interrupt" (lambda () (slime-sldb-level= 1)) 5)
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-continue))
  (slime-wait-condition "running" (lambda ()
                                    (and (slime-busy-p)
                                         (not (sldb-get-default-buffer)))) 5)
  (slime-interrupt)
  (slime-wait-condition "Second interrupt" (lambda () (slime-sldb-level= 1)) 5)
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-quit))
  (slime-sync-to-top-level 5)
  (slime-check-top-level))

(def-slime-test interactive-eval
    ()
    "Test interactive eval and continuing from the debugger."
    '(())
  (slime-check-top-level)
  (lexical-let ((done nil))
    (let ((sldb-hook (lambda () (sldb-continue) (setq done t))))
      (slime-interactive-eval
       "(progn\
 (cerror \"foo\" \"restart\")\
 (cerror \"bar\" \"restart\")\
 (+ 1 2))")
      (while (not done) (slime-accept-process-output))
      (slime-sync-to-top-level 5)
      (slime-check-top-level)
      (unless noninteractive
        (let ((message (current-message)))
          (slime-check "Minibuffer contains: \"3\""
            (equal "=> 3 (2 bits, #x3, #o3, #b11)" message)))))))

(def-slime-test report-condition-with-circular-list
    (format-control format-argument)
    "Test conditions involving circular lists."
    '(("~a" "(let ((x (cons nil nil))) (setf (cdr x) x))")
      ("~a" "(let ((x (cons nil nil))) (setf (car x) x))")
      ("~a" "(let ((x (cons (make-string 100000 :initial-element #\\X) nil)))\
                (setf (cdr x) x))"))
  (slime-check-top-level)
  (lexical-let ((done nil))
    (let ((sldb-hook (lambda () (sldb-continue) (setq done t))))
      (slime-interactive-eval
       (format "(progn (cerror \"foo\" %S %s) (+ 1 2))"
               format-control format-argument))
      (while (not done) (slime-accept-process-output))
      (slime-sync-to-top-level 5)
      (slime-check-top-level)
      (unless noninteractive
        (let ((message (current-message)))
          (slime-check "Minibuffer contains: \"3\""
            (equal "=> 3 (2 bits, #x3, #o3, #b11)" message)))))))

(def-slime-test interrupt-bubbling-idiot
    ()
    "Test interrupting a loop that sends a lot of output to Emacs."
    '(())
  (slime-accept-process-output nil 1)
  (slime-check-top-level)
  (slime-eval-async '(cl:loop :for i :from 0 :do (cl:progn (cl:print i)
                                                           (cl:finish-output)))
                    (lambda (_) )
                    "CL-USER")
  (sleep-for 1)
  (slime-interrupt)
  (slime-wait-condition "Debugger visible"
                        (lambda ()
                          (and (slime-sldb-level= 1)
                               (get-buffer-window (sldb-get-default-buffer))))
                        30)
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-quit))
  (slime-sync-to-top-level 5))

(def-slime-test (interrupt-encode-message (:style :sigio))
    ()
    "Test interrupt processing during swank::encode-message"
    '(())
  (slime-eval-async '(cl:loop :for i :from 0
                              :do (swank::background-message "foo ~d" i)))
  (sleep-for 1)
  (slime-eval-async '(cl:/ 1 0))
  (slime-wait-condition "Debugger visible"
                        (lambda ()
                          (and (slime-sldb-level= 1)
                               (get-buffer-window (sldb-get-default-buffer))))
                        30)
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-quit))
  (slime-sync-to-top-level 5))

(def-slime-test inspector
    (exp)
    "Test basic inspector workingness."
    '(((let ((h (make-hash-table)))
         (loop for i below 10 do (setf (gethash i h) i))
         h))
      ((make-array 10))
      ((make-list 10))
      ('cons)
      (#'cons))
  (slime-inspect (prin1-to-string exp))
  (assert (not (slime-inspector-visible-p)))
  (slime-wait-condition "Inspector visible" #'slime-inspector-visible-p 5)
  (with-current-buffer (window-buffer (selected-window))
    (slime-inspector-quit))
  (slime-wait-condition "Inspector closed"
                        (lambda () (not (slime-inspector-visible-p)))
                        5)
  (slime-sync-to-top-level 1))

(defun slime-buffer-visible-p (name)
  (let ((buffer (window-buffer (selected-window))))
    (string-match name (buffer-name buffer))))

(defun slime-inspector-visible-p ()
  (slime-buffer-visible-p (slime-buffer-name :inspector)))

(defun slime-execute-as-command (name)
  "Execute `name' as if it was done by the user through the
Command Loop. Similiar to `call-interactively' but also pushes on
the buffer's undo-list."
  (undo-boundary)
  (call-interactively name))

(def-slime-test macroexpand
    (macro-defs bufcontent expansion1 search-str expansion2)
    "foo"
    '((("(defmacro qwertz (&body body) `(list :qwertz ',body))"
        "(defmacro yxcv (&body body) `(list :yxcv (qwertz ,@body)))")
       "(yxcv :A :B :C)"
       "(list :yxcv (qwertz :a :b :c))"
       "(qwertz"
       "(list :yxcv (list :qwertz '(:a :b :c)))"))
  (slime-check-top-level)
  (setq slime-buffer-package ":swank")
  (with-temp-buffer
    (lisp-mode)
    (dolist (def macro-defs)
      (slime-compile-string def 0)
      (slime-sync-to-top-level 5))
    (insert bufcontent)
    (goto-char (point-min))
    (slime-execute-as-command 'slime-macroexpand-1)
    (slime-wait-condition "Macroexpansion buffer visible"
                          (lambda ()
                            (slime-buffer-visible-p
                             (slime-buffer-name :macroexpansion)))
                          5)
    (with-current-buffer (get-buffer (slime-buffer-name :macroexpansion))
      (slime-test-expect "Initial macroexpansion is correct"
                         expansion1
                         (downcase (buffer-string))
                         #'slime-test-macroexpansion=)
      (search-forward search-str)
      (backward-up-list)
      (slime-execute-as-command 'slime-macroexpand-1-inplace)
      (slime-sync-to-top-level 3)
      (slime-test-expect "In-place macroexpansion is correct"
                         expansion2
                         (downcase (buffer-string))
                         #'slime-test-macroexpansion=)
      (slime-execute-as-command 'slime-macroexpand-undo)
      (slime-test-expect "Expansion after undo is correct"
                         expansion1
                         (downcase (buffer-string))
                         #'slime-test-macroexpansion=)))
    (setq slime-buffer-package ":cl-user"))

(defun slime-test-macroexpansion= (string1 string2)
  (let ((string1 (replace-regexp-in-string " *\n *" " " string1))
        (string2 (replace-regexp-in-string " *\n *" " " string2)))
    (equal string1 string2)))

(def-slime-test indentation (buffer-content point-markers)
        "Check indentation update to work correctly."
    '(("
\(in-package :swank)

\(defmacro with-lolipop (&body body)
  `(progn ,@body))

\(defmacro lolipop (&body body)
  `(progn ,@body))

\(with-lolipop
  1
  2
  42)

\(lolipop
  1
  2
  23)
"
       ("23" "42")))
  (with-temp-buffer
    (lisp-mode)
    (slime-lisp-mode-hook)
    (insert buffer-content)
    (slime-compile-region (point-min) (point-max))
    (slime-sync-to-top-level 3)
    (slime-update-indentation)
    (slime-sync-to-top-level 3)
    (dolist (marker point-markers)
      (search-backward marker)
      (beginning-of-defun)
      (indent-sexp))
    (slime-test-expect "Correct buffer content"
                       buffer-content
                       (substring-no-properties (buffer-string)))))

(def-slime-test break
    (times exp)
    "Test whether BREAK invokes SLDB."
    (let ((exp1 '(break)))
      `((1 ,exp1) (2 ,exp1) (3 ,exp1)))
  (slime-accept-process-output nil 0.2)
  (slime-check-top-level)
  (slime-eval-async
   `(cl:eval (cl:read-from-string
              ,(prin1-to-string `(dotimes (i ,times)
                                   (unless (= i 0)
                                     (swank::sleep-for 1))
                                   ,exp)))))
  (dotimes (_i times)
    (slime-wait-condition "Debugger visible"
                          (lambda ()
                            (and (slime-sldb-level= 1)
                                 (get-buffer-window
                                  (sldb-get-default-buffer))))
                          3)
    (with-current-buffer (sldb-get-default-buffer)
      (sldb-continue))
    (slime-wait-condition "sldb closed"
                          (lambda () (not (sldb-get-default-buffer)))
                          0.5))
  (slime-sync-to-top-level 1))

(def-slime-test (break2 (:fails-for "cmucl" "allegro" "ccl"))
    (times exp)
    "Backends should arguably make sure that BREAK does not depend
on *DEBUGGER-HOOK*."
    (let ((exp2
           '(block outta
              (let ((*debugger-hook* (lambda (c h) (return-from outta 42))))
                (break)))))
      `((1 ,exp2) (2 ,exp2) (3 ,exp2)))
  (slime-test-break times exp))

(def-slime-test locally-bound-debugger-hook
    ()
    "Test that binding *DEBUGGER-HOOK* locally works properly."
    '(())
  (slime-accept-process-output nil 1)
  (slime-check-top-level)
  (slime-compile-string
   (prin1-to-string `(defun cl-user::quux ()
                       (block outta
                         (let ((*debugger-hook*
                                (lambda (c hook)
                                  (declare (ignore c hook))
                                  (return-from outta 42))))
                           (error "FOO")))))
   0)
  (slime-sync-to-top-level 2)
  (slime-eval-async '(cl-user::quux))
  ;; FIXME: slime-wait-condition returns immediately if the test returns true
  (slime-wait-condition "Checking that Debugger does not popup"
                        (lambda ()
                          (not (sldb-get-default-buffer)))
                        3)
  (slime-sync-to-top-level 5))

(def-slime-test end-of-file
    (expr)
    "Signalling END-OF-FILE should invoke the debugger."
    '(((cl:read-from-string ""))
      ((cl:error 'cl:end-of-file)))
  (let ((value (slime-eval
                `(cl:let ((condition nil))
                         (cl:with-simple-restart
                          (cl:continue "continue")
                          (cl:let ((cl:*debugger-hook*
                                    (cl:lambda (c h)
                                               (cl:setq condition c)
                                               (cl:continue))))
                                  ,expr))
                         (cl:and (cl:typep condition 'cl:condition)
                                 (cl:string (cl:type-of condition)))))))
    (slime-test-expect "Debugger invoked" "END-OF-FILE" value)))

(def-slime-test interrupt-at-toplevel
    ()
    "Let's see what happens if we send a user interrupt at toplevel."
    '(())
  (slime-check-top-level)
  (unless (and (eq (slime-communication-style) :spawn)
               (not (featurep 'slime-repl)))
    (slime-interrupt)
    (slime-wait-condition
     "Debugger visible"
     (lambda ()
       (and (slime-sldb-level= 1)
            (get-buffer-window (sldb-get-default-buffer))))
     5)
    (with-current-buffer (sldb-get-default-buffer)
      (sldb-quit))
    (slime-sync-to-top-level 5)))

(def-slime-test interrupt-in-debugger (interrupts continues)
    "Let's see what happens if we interrupt the debugger.
INTERRUPTS ... number of nested interrupts
CONTINUES  ... how often the continue restart should be invoked"
    '((1 0) (2 1) (4 2))
  (slime-check "No debugger" (not (sldb-get-default-buffer)))
  (when (and (eq (slime-communication-style) :spawn)
             (not (featurep 'slime-repl)))
    (slime-eval-async '(swank::without-slime-interrupts
                        (swank::receive)))
    (sit-for 0.2))
  (dotimes (i interrupts)
    (slime-interrupt)
    (let ((level (1+ i)))
      (slime-wait-condition (format "Debug level %d reachend" level)
                            (lambda () (equal (sldb-level) level))
                            2)))
  (dotimes (i continues)
    (with-current-buffer (sldb-get-default-buffer)
      (sldb-continue))
    (let ((level (- interrupts (1+ i))))
      (slime-wait-condition (format "Return to debug level %d" level)
                            (lambda () (equal (sldb-level) level))
                            2)))
  (with-current-buffer (sldb-get-default-buffer)
    (sldb-quit))
  (slime-sync-to-top-level 1))

(def-slime-test flow-control
    (n delay interrupts)
    "Let Lisp produce output faster than Emacs can consume it."
    `((400 0.03 3))
  (slime-skip-test "test is currently unstable")
  (slime-check "No debugger" (not (sldb-get-default-buffer)))
  (slime-eval-async `(swank:flow-control-test ,n ,delay))
  (sleep-for 0.2)
  (dotimes (_i interrupts)
    (slime-interrupt)
    (slime-wait-condition "In debugger" (lambda () (slime-sldb-level= 1)) 5)
    (slime-check "In debugger" (slime-sldb-level= 1))
    (with-current-buffer (sldb-get-default-buffer)
      (sldb-continue))
    (slime-wait-condition "No debugger" (lambda () (slime-sldb-level= nil)) 3)
    (slime-check "Debugger closed" (slime-sldb-level= nil)))
  (slime-sync-to-top-level 8))

(def-slime-test sbcl-world-lock
    (n delay)
    "Print something from *MACROEXPAND-HOOK*.
In SBCL, the compiler grabs a lock which can be problematic because
no method dispatch code can be generated for other threads.
This test will fail more likely before dispatch caches are warmed up."
    '((10 0.03)
      ;;((cl:+ swank::send-counter-limit 10) 0.03)
      )
  (slime-test-expect "no error"
		     123
		     (slime-eval
		      `(cl:let ((cl:*macroexpand-hook*
				 (cl:lambda (fun form env)
					    (swank:flow-control-test ,n ,delay)
					    (cl:funcall fun form env))))
			       (cl:eval '(cl:macrolet ((foo () 123))
					   (foo)))))))

(def-slime-test (disconnect-one-connection (:style :spawn)) ()
    "`slime-disconnect' should disconnect only the current connection"
    '(())
  (let ((connection-count (length slime-net-processes))
        (old-connection slime-default-connection)
        (slime-connected-hook nil))
    (unwind-protect
         (let ((slime-dispatching-connection
                (slime-connect "localhost"
                               ;; Here we assume that the request will
                               ;; be evaluated in its own thread.
                               (slime-eval `(swank:create-server
                                             :port 0 ; use random port
                                             :style :spawn
                                             :dont-close nil)))))
           (slime-sync-to-top-level 3)
           (slime-disconnect)
           (slime-test-expect "Number of connections must remane the same"
                              connection-count
                              (length slime-net-processes)))
      (slime-select-connection old-connection))))

(def-slime-test disconnect-and-reconnect
    ()
    "Close the connetion.
Confirm that the subprocess continues gracefully.
Reconnect afterwards."
    '(())
  (slime-check-top-level)
  (let* ((c (slime-connection))
         (p (slime-inferior-process c)))
    (with-current-buffer (process-buffer p)
      (erase-buffer))
    (delete-process c)
    (assert (equal (process-status c) 'closed) nil "Connection not closed")
    (slime-accept-process-output nil 0.1)
    (assert (equal (process-status p) 'run) nil "Subprocess not running")
    (with-current-buffer (process-buffer p)
      (assert (< (buffer-size) 500) nil "Unusual output"))
    (slime-inferior-connect p (slime-inferior-lisp-args p))
    (lexical-let ((hook nil) (p p))
      (setq hook (lambda ()
                   (slime-test-expect
                    "We are connected again" p (slime-inferior-process))
                   (remove-hook 'slime-connected-hook hook)))
      (add-hook 'slime-connected-hook hook)
      (slime-wait-condition "Lisp restarted"
                            (lambda ()
                              (not (member hook slime-connected-hook)))
                            5))))


;;;; SLIME-loading tests that launch separate Emacsen
;;;;
(cl-defun slime-test-recipe-test-for (&key preflight
                                           takeoff
                                           landing)
  
  (let ((success nil)
        (test-file (make-temp-file "slime-recipe-" nil ".el"))
        (test-forms
         `((require 'cl)
           (labels
               ((die
                 (reason &optional more)
                 (princ reason)
                 (terpri)
                 (and more (pp more))
                 (kill-emacs 254)))
             (condition-case err
                 (progn ,@preflight)
               (error
                (die "Unexpected error running preflight forms"
                     err)))
             (add-hook
              'slime-connected-hook
              #'(lambda ()
                  (condition-case err
                      (progn
                        ,@landing
                        (kill-emacs 0))
                    (error
                     (die "Unexpected error running landing forms"
                          err))))
              t)
             (condition-case err
                 (progn
                   ,@takeoff
                   ,(when (null landing) '(kill-emacs 0)))
               (error
                (die "Unexpected error running takeoff forms"
                     err)))
             (with-timeout
                 (20
                  (die "Timeout waiting for recipe test to finish."
                       takeoff))
               (while t (sit-for 1)))))))
    (unwind-protect
        (progn
          (with-temp-buffer
            (mapc #'insert (mapcar #'pp-to-string test-forms))
            (write-file test-file))
          (with-temp-buffer
            (let ((retval
                   (call-process (concat invocation-directory invocation-name)
                                 nil (list t nil) nil
                                 "-Q" "--batch"
                                 "-l" test-file)))
              (unless (= 0 retval)
                (ert-fail (buffer-substring
                           (+ (goto-char (point-min)) (skip-chars-forward " \t\n"))
                           (+ (goto-char (point-max)) (skip-chars-backward " \t\n")))))))
          (setq success t))
      (if success (delete-file test-file)
        (message "Test failed: keeping %s for inspection" test-file)))))

(define-slime-ert-test readme-recipe ()
  "Test the README.md's autoload recipe."
  (slime-test-recipe-test-for
   :preflight `((add-to-list 'load-path ,slime-path)
                (require 'slime-autoloads)
                (setq inferior-lisp-program ,inferior-lisp-program)
                (setq slime-contribs '(slime-fancy)))
   
   :takeoff `((call-interactively 'slime))
   
   :landing `((unless (and (featurep 'slime-repl)
                           (find 'swank-repl slime-required-modules))
                (die "slime-repl not loaded properly"))
              (with-current-buffer (slime-repl-buffer)
                (unless (and (string-match "^; +SLIME" (buffer-string))
                             (string-match "CL-USER> *$" (buffer-string)))
                  (die "REPL prompt not properly setup"
                       (buffer-substring-no-properties (point-min) (point-max))))))))

(define-slime-ert-test traditional-recipe ()
  "Test the README.md's traditional recipe."
  (slime-test-recipe-test-for
   :preflight `((add-to-list 'load-path ,slime-path)
                (require 'slime)
                (setq inferior-lisp-program ,inferior-lisp-program)
                (slime-setup '(slime-fancy)))
   
   :takeoff `((call-interactively 'slime))
   
   :landing `((unless (and (featurep 'slime-repl)
                           (find 'swank-repl slime-required-modules))
                (die "slime-repl not loaded properly"))
              (with-current-buffer (slime-repl-buffer)
                (unless (and (string-match "^; +SLIME" (buffer-string))
                             (string-match "CL-USER> *$" (buffer-string)))
                  (die "REPL prompt not properly setup"
                       (buffer-substring-no-properties (point-min) (point-max))))))))

(define-slime-ert-test readme-recipe-autoload-on-lisp-visit ()
  "Test more autoload bits in README.md's installation recipe."
  (slime-test-recipe-test-for
   :preflight `((add-to-list 'load-path ,slime-path)
                (require 'slime-autoloads))
   
   :takeoff `((if (featurep 'slime)
                  (die "Didn't expect SLIME to be loaded so early!"))
              (find-file ,(make-temp-file "slime-lisp-source-file" nil ".lisp"))
              (unless (featurep 'slime)
                (die "Expected SLIME to be fully loaded by now")))))



(provide 'slime-tests)