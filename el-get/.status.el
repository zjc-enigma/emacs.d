((git-emacs status "installed" recipe
            (:name git-emacs :description "Yet another git emacs mode for newbies" :type github :pkgname "tsgates/git-emacs" :features git-emacs))
 (htmlize status "installed" recipe
          (:type github :pkgname "emacsmirror/htmlize" :name htmlize :website "http://www.emacswiki.org/emacs/Htmlize" :description "Convert buffer text and decorations to HTML." :type emacsmirror :localname "htmlize.el"))
 (metaweblog status "installed" recipe
             (:name metaweblog :description "Metaweblog" :type github :pkgname "punchagan/metaweblog"))
 (xml-rpc-el status "installed" recipe
             (:name xml-rpc-el :description "An elisp implementation of clientside XML-RPC" :type bzr :url "lp:xml-rpc-el")))
