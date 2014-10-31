((htmlize status "installed" recipe
          (:type github :pkgname "emacsmirror/htmlize" :name htmlize :website "http://www.emacswiki.org/emacs/Htmlize" :description "Convert buffer text and decorations to HTML." :type emacsmirror :localname "htmlize.el"))
 (metaweblog status "installed" recipe
             (:name metaweblog :description "Metaweblog" :type github :pkgname "punchagan/metaweblog"))
 (org-jekyll status "installed" recipe
             (:name org-jekyll :description "Blog from org-mode using jekyll" :type github :pkgname "juanre/org-jekyll" :features org-jekyll))
 (xml-rpc-el status "installed" recipe
             (:name xml-rpc-el :description "An elisp implementation of clientside XML-RPC" :type bzr :url "lp:xml-rpc-el")))
