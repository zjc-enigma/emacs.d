((cl-lib status "installed" recipe
         (:name cl-lib :builtin "24.3" :type elpa :description "Properly prefixed CL functions and macros" :url "http://elpa.gnu.org/packages/cl-lib.html"))
 (cssh status "installed" recipe
       (:name cssh :website "https://github.com/dimitri/cssh" :description "ClusterSSH meets Emacs " :type github :pkgname "dimitri/cssh" :features cssh))
 (git-emacs status "installed" recipe
            (:name git-emacs :description "Yet another git emacs mode for newbies" :type github :pkgname "tsgates/git-emacs" :features git-emacs))
 (git-modes status "installed" recipe
            (:name git-modes :description "GNU Emacs modes for various Git-related files" :type github :pkgname "magit/git-modes"))
 (htmlize status "installed" recipe
          (:type github :pkgname "emacsmirror/htmlize" :name htmlize :website "http://www.emacswiki.org/emacs/Htmlize" :description "Convert buffer text and decorations to HTML." :type emacsmirror :localname "htmlize.el"))
 (magit status "installed" recipe
        (:name magit :website "https://github.com/magit/magit#readme" :description "It's Magit! An Emacs mode for Git." :type github :pkgname "magit/magit" :depends
               (cl-lib git-modes)
               :info "." :compile "magit.*.el\\'" :build
               `(("make" "docs"))
               :build/berkeley-unix
               (("gmake docs"))
               :build/windows-nt
               (progn nil)))
 (metaweblog status "installed" recipe
             (:name metaweblog :description "Metaweblog" :type github :pkgname "punchagan/metaweblog"))
 (org-jekyll status "installed" recipe
             (:name org-jekyll :description "Blog from org-mode using jekyll" :type github :pkgname "juanre/org-jekyll" :features org-jekyll))
 (ssh status "installed" recipe
      (:name ssh :website "http://www.splode.com/~friedman/software/emacs-lisp/#ssh" :description "This is a comint-based interface for connecting to remote hosts via ssh." :type http :url "http://www.splode.com/~friedman/software/emacs-lisp/src/ssh.el"))
 (xml-rpc-el status "installed" recipe
             (:name xml-rpc-el :description "An elisp implementation of clientside XML-RPC" :type bzr :url "lp:xml-rpc-el")))
