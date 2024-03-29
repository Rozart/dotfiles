;; -*- mode: emacs-lisp -*-
;; This file is loaded by Spacemacs at startup.
;; It must be stored in your home directory.

(defun dotspacemacs/layers ()
  "Configuration Layers declaration.
You should not put any user code in this function besides modifying the variable
values."
  (setq-default
   ;; Base distribution to use. This is a layer contained in the directory
   ;; `+distribution'. For now available distributions are `spacemacs-base'
   ;; or `spacemacs'. (default 'spacemacs)
   dotspacemacs-distribution 'spacemacs
   ;; Lazy installation of layers (i.e. layers are installed only when a file
   ;; with a supported type is opened). Possible values are `all', `unused'
   ;; and `nil'. `unused' will lazy install only unused layers (i.e. layers
   ;; not listed in variable `dotspacemacs-configuration-layers'), `all' will
   ;; lazy install any layer that support lazy installation even the layers
   ;; listed in `dotspacemacs-configuration-layers'. `nil' disable the lazy
   ;; installation feature and you have to explicitly list a layer in the
   ;; variable `dotspacemacs-configuration-layers' to install it.
   ;; (default 'unused)
   dotspacemacs-enable-lazy-installation 'unused
   ;; If non-nil then Spacemacs will ask for confirmation before installing
   ;; a layer lazily. (default t)
   dotspacemacs-ask-for-lazy-installation t
   ;; If non-nil layers with lazy install support are lazy installed.
   ;; List of additional paths where to look for configuration layers.
   ;; Paths must have a trailing slash (i.e. `~/.mycontribs/')
   dotspacemacs-configuration-layer-path '()
   ;; List of configuration layers to load.
   dotspacemacs-configuration-layers
   '(vimscript
     nginx
     ;; ----------------------------------------------------------------
     ;; Programming languages layers
     ;; ----------------------------------------------------------------
     emacs-lisp
     (lsp :variables
          lsp-restart 'ignore
          lsp-python-ms-python-executable-cmd "python3")
     (java :variables
           java-backend 'lsp)
     go
     kotlin
     (python :variables
             python-auto-set-local-pyenv-version t
             python-backend 'lsp
             python-lsp-server 'mspyls
             python-lsp-git-root "~/Dev/python-language-server"
             python-formatter 'black
             python-test-runner '(pytest nose)
             python-fill-column 88)
     dap
     clojure
     javascript
     typescript
     json
     imenu-list
     ;; ----------------------------------------------------------------
     ;; File formats layers
     ;; ----------------------------------------------------------------
     ipython-notebook
     html
     csv
     yaml
     markdown
     pdf
     ;; ----------------------------------------------------------------
     ;; Entertainment and utility layers
     ;; ----------------------------------------------------------------
     spotify
     emoji
     search-engine
     restclient
     git
     github
     osx
     docker
     ;; ----------------------------------------------------------------
     ;; Example of useful layers you may want to use right away.
     ;; Uncomment some layer names and press <SPC f e R> (Vim style) or
     ;; <M-m f e R> (Emacs style) to install them.
     ;; ----------------------------------------------------------------
     themes-megapack
     theming
     helm
     (treemacs :variables
               treemacs-use-follow-mode t)
     multiple-cursors
     unicode-fonts
     (auto-completion :variables
                      auto-completion-tab-key-behavior 'cycle
                      auto-completion-return-key-behavior 'complete
                      auto-completion-enable-help-tooltip t
                      auto-completion-enable-sort-by-usage t
                      auto-completion-idle-delay 0)
     (org :variables
          org-enable-org-journal-support t)
     (ibuffer :variables
              ibuffer-group-buffers-by 'projects)

     (shell :variables
            shell-default-shell 'eshell
            shell-default-position 'bottom
            shell-default-height 30)
     spell-checking
     syntax-checking
     pandoc
     )
   ;; List of additional packages that will be installed without being
   ;; wrapped in a layer. If you need some configuration for these
   ;; packages, then consider creating a layer. You can also put the
   ;; configuration in `dotspacemacs/user-config'.
   dotspacemacs-additional-packages '(all-the-icons
                                      spaceline-all-the-icons
                                      company-lsp
                                      kubernetes
                                      kubernetes-evil
                                      (sunrise-commander :location (recipe :fetcher github :repo "escherdragon/sunrise-commander"))
                                      )
   ;; A list of packages that cannot be updated.
   dotspacemacs-frozen-packages '()
   ;; A list of packages that will not be installed and loaded.
   dotspacemacs-excluded-packages '()
   ;; Defines the behaviour of Spacemacs when installing packages.
   ;; Possible values are `used-only', `used-but-keep-unused' and `all'.
   ;; `used-only' installs only explicitly used packages and uninstall any
   ;; unused packages as well as their unused dependencies.
   ;; `used-but-keep-unused' installs only the used packages but won't uninstall
   ;; them if they become unused. `all' installs *all* packages supported by
   ;; Spacemacs and never uninstall them. (default is `used-only')
   dotspacemacs-install-packages 'used-only))

(defun dotspacemacs/init ()
  "Initialization function.
This function is called at the very startup of Spacemacs initialization
before layers configuration.
You should not put any user code in there besides modifying the variable
values."
  ;; This setq-default sexp is an exhaustive list of all the supported
  ;; spacemacs settings.
  (setq-default
   ;; If non nil ELPA repositories are contacted via HTTPS whenever it's
   ;; possible. Set it to nil if you have no way to use HTTPS in your
   ;; environment, otherwise it is strongly recommended to let it set to t.
   ;; This variable has no effect if Emacs is launched with the parameter
   ;; `--insecure' which forces the value of this variable to nil.
   ;; (default t)
   dotspacemacs-elpa-https t
   ;; Maximum allowed time in seconds to contact an ELPA repository.
   dotspacemacs-elpa-timeout 5

   ;; Set `gc-cons-threshold' and `gc-cons-percentage' when startup finishes.
   ;; This is an advanced option and should not be changed unless you suspect
   ;; performance issues due to garbage collection operations.
   ;; (default '(100000000 0.1))
   dotspacemacs-gc-cons '(100000000 0.1)

   ;; If non-nil then Spacelpa repository is the primary source to install
   ;; a locked version of packages. If nil then Spacemacs will install the
   ;; latest version of packages from MELPA. (default nil)
   dotspacemacs-use-spacelpa nil

   ;; If non-nil then verify the signature for downloaded Spacelpa archives.
   ;; (default nil)
   dotspacemacs-verify-spacelpa-archives nil

   ;; If non-nil then spacemacs will check for updates at startup
   ;; when the current branch is not `develop'. Note that checking for
   ;; new versions works via git commands, thus it calls GitHub services
   ;; whenever you start Emacs. (default nil)
   dotspacemacs-check-for-update nil
   ;; If non-nil, a form that evaluates to a package directory. For example, to
   ;; use different package directories for different Emacs versions, set this
   ;; to `emacs-version'. (default 'emacs-version)
   dotspacemacs-elpa-subdirectory 'emacs-version

   ;; One of `vim', `emacs' or `hybrid'.
   ;; `hybrid' is like `vim' except that `insert state' is replaced by the
   ;; `hybrid state' with `emacs' key bindings. The value can also be a list
   ;; with `:variables' keyword (similar to layers). Check the editing styles
   ;; section of the documentation for details on available variables.
   ;; (default 'vim)
   dotspacemacs-editing-style 'vim
   ;; If non nil output loading progress in `*Messages*' buffer. (default nil)
   dotspacemacs-verbose-loading nil
   ;; Specify the startup banner. Default value is `official', it displays
   ;; the official spacemacs logo. An integer value is the index of text
   ;; banner, `random' chooses a random text banner in `core/banners'
   ;; directory. A string value must be a path to an image format supported
   ;; by your Emacs build.
   ;; If the value is nil then no banner is displayed. (default 'official)
   dotspacemacs-startup-banner 'official
   ;; List of items to show in startup buffer or an association list of
   ;; the form `(list-type . list-size)`. If nil then it is disabled.
   ;; Possible values for list-type are:
   ;; `recents' `bookmarks' `projects' `agenda' `todos'.
   ;; List sizes may be nil, in which case
   ;; `spacemacs-buffer-startup-lists-length' takes effect.
   dotspacemacs-startup-lists '((todos)
                                (agenda)
                                (recents . 5))
   ;; True if the home buffer should respond to resize events. (default t)
   dotspacemacs-startup-buffer-responsive t

   ;; Default major mode for a new empty buffer. Possible values are mode
   ;; names such as `text-mode'; and `nil' to use Fundamental mode.
   ;; (default `text-mode')
   dotspacemacs-new-empty-buffer-major-mode 'text-mode

   ;; Default major mode of the scratch buffer (default `text-mode')
   dotspacemacs-scratch-mode 'text-mode

   ;; Initial message in the scratch buffer, such as "Welcome to Spacemacs!"
   ;; (default nil)
   dotspacemacs-initial-scratch-message nil

   ;; List of themes, the first of the list is loaded when spacemacs starts.
   ;; Press `SPC T n' to cycle to the next theme in the list (works great
   ;; with 2 themes variants, one dark and one light)
   dotspacemacs-themes '(gruvbox-dark-soft gruvbox-light-medium)

   ;; If non-nil the cursor color matches the state color in GUI Emacs.
   ;; (default t)
   dotspacemacs-colorize-cursor-according-to-state t
   ;; Default font, or prioritized list of fonts. `powerline-scale' allows to
   ;; quickly tweak the mode-line size to make separators look not too crappy.
   dotspacemacs-default-font '("Iosevka" :size 13 :weight light)

   dotspacemacs-mode-line-theme '(all-the-icons :separator arrow :separator-scale 1.8)
   ;; The leader key
   dotspacemacs-leader-key "SPC"
   ;; The key used for Emacs commands (M-x) (after pressing on the leader key).
   ;; (default "SPC")
   dotspacemacs-emacs-command-key "SPC"
   ;; The key used for Vim Ex commands (default ":")
   dotspacemacs-ex-command-key ":"
   ;; The leader key accessible in `emacs state' and `insert state'
   ;; (default "M-m")
   dotspacemacs-emacs-leader-key "M-m"
   ;; Major mode leader key is a shortcut key which is the equivalent of
   ;; pressing `<leader> m`. Set it to `nil` to disable it. (default ",")
   dotspacemacs-major-mode-leader-key ","
   ;; Major mode leader key accessible in `emacs state' and `insert state'.
   ;; (default "C-M-m")
   dotspacemacs-major-mode-emacs-leader-key "C-M-m"
   ;; These variables control whether separate commands are bound in the GUI to
   ;; the key pairs C-i, TAB and C-m, RET.
   ;; Setting it to a non-nil value, allows for separate commands under <C-i>
   ;; and TAB or <C-m> and RET.
   ;; In the terminal, these pairs are generally indistinguishable, so this only
   ;; works in the GUI. (default nil)
   dotspacemacs-distinguish-gui-tab nil
   ;; If non nil `Y' is remapped to `y$' in Evil states. (default nil)
   dotspacemacs-remap-Y-to-y$ nil
   ;; If non-nil, the shift mappings `<' and `>' retain visual state if used
   ;; there. (default t)
   dotspacemacs-retain-visual-state-on-shift t
   ;; If non-nil, J and K move lines up and down when in visual mode.
   ;; (default nil)
   dotspacemacs-visual-line-move-text t
   ;; If non nil, inverse the meaning of `g' in `:substitute' Evil ex-command.
   ;; (default nil)
   dotspacemacs-ex-substitute-global nil
   ;; Name of the default layout (default "Default")
   dotspacemacs-default-layout-name "Default"
   ;; If non nil the default layout name is displayed in the mode-line.
   ;; (default nil)
   dotspacemacs-display-default-layout nil
   ;; If non nil then the last auto saved layouts are resume automatically upon
   ;; start. (default nil)
   dotspacemacs-auto-resume-layouts nil

   ;; If non-nil, auto-generate layout name when creating new layouts. Only has
   ;; effect when using the "jump to layout by number" commands. (default nil)
   dotspacemacs-auto-generate-layout-names nil

   ;; Size (in MB) above which spacemacs will prompt to open the large file
   ;; literally to avoid performance issues. Opening a file literally means that
   ;; no major mode or minor modes are active. (default is 1)
   dotspacemacs-large-file-size 1
   ;; Location where to auto-save files. Possible values are `original' to
   ;; auto-save the file in-place, `cache' to auto-save the file to another
   ;; file stored in the cache directory and `nil' to disable auto-saving.
   ;; (default 'cache)
   dotspacemacs-auto-save-file-location 'cache
   ;; Maximum number of rollback slots to keep in the cache. (default 5)
   dotspacemacs-max-rollback-slots 20
   ;; If non nil, `helm' will try to minimize the space it uses. (default nil)
   dotspacemacs-helm-resize nil
   ;; if non nil, the helm header is hidden when there is only one source.
   ;; (default nil)
   dotspacemacs-helm-no-header nil
   ;; define the position to display `helm', options are `bottom', `top',
   ;; `left', or `right'. (default 'bottom)
   dotspacemacs-helm-position 'bottom
   ;; Controls fuzzy matching in helm. If set to `always', force fuzzy matching
   ;; in all non-asynchronous sources. If set to `source', preserve individual
   ;; source settings. Else, disable fuzzy matching in all sources.
   ;; (default 'always)
   dotspacemacs-helm-use-fuzzy 'always
   ;; If non nil the paste micro-state is enabled. When enabled pressing `p`
   ;; several times cycle between the kill ring content. (default nil)
   dotspacemacs-enable-paste-transient-state nil
   ;; Which-key delay in seconds. The which-key buffer is the popup listing
   ;; the commands bound to the current keystroke sequence. (default 0.4)
   dotspacemacs-which-key-delay 0.4
   ;; Which-key frame position. Possible values are `right', `bottom' and
   ;; `right-then-bottom'. right-then-bottom tries to display the frame to the
   ;; right; if there is insufficient space it displays it at the bottom.
   ;; (default 'bottom)
   dotspacemacs-which-key-position 'bottom

   ;; Control where `switch-to-buffer' displays the buffer. If nil,
   ;; `switch-to-buffer' displays the buffer in the current window even if
   ;; another same-purpose window is available. If non-nil, `switch-to-buffer'
   ;; displays the buffer in a same-purpose window even if the buffer can be
   ;; displayed in the current window. (default nil)
   dotspacemacs-switch-to-buffer-prefers-purpose nil

   ;; If non-nil a progress bar is displayed when spacemacs is loading. This
   ;; may increase the boot time on some systems and emacs builds, set it to
   ;; nil to boost the loading time. (default t)
   dotspacemacs-loading-progress-bar t

   ;; If non-nil the frame is fullscreen when Emacs starts up. (default nil)
   ;; (Emacs 24.4+ only)
   dotspacemacs-fullscreen-at-startup nil
   ;; If non nil `spacemacs/toggle-fullscreen' will not use native fullscreen.
   ;; Use to disable fullscreen animations in OSX. (default nil)
   dotspacemacs-fullscreen-use-non-native nil
   ;; If non nil the frame is maximized when Emacs starts up.
   ;; Takes effect only if `dotspacemacs-fullscreen-at-startup' is nil.
   ;; (default nil) (Emacs 24.4+ only)
   dotspacemacs-maximized-at-startup t

   ;; If non-nil the frame is undecorated when Emacs starts up. Combine this
   ;; variable with `dotspacemacs-maximized-at-startup' in OSX to obtain
   ;; borderless fullscreen. (default nil)
   dotspacemacs-undecorated-at-startup nil

   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's active or selected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-active-transparency 90
   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's inactive or deselected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-inactive-transparency 90

   ;; If non-nil show the titles of transient states. (default t)
   dotspacemacs-show-transient-state-title t

   ;; If non-nil show the color guide hint for transient state keys. (default t)
   dotspacemacs-show-transient-state-color-guide t

   ;; If non-nil unicode symbols are displayed in the mode line.
   ;; If you use Emacs as a daemon and wants unicode characters only in GUI set
   ;; the value to quoted `display-graphic-p'. (default t)
   dotspacemacs-mode-line-unicode-symbols t

   ;; If non-nil smooth scrolling (native-scrolling) is enabled. Smooth
   ;; scrolling overrides the default behavior of Emacs which recenters point
   ;; when it reaches the top or bottom of the screen. (default t)
   dotspacemacs-smooth-scrolling t

   ;; Control line numbers activation.
   ;; If set to `t', `relative' or `visual' then line numbers are enabled in all
   ;; `prog-mode' and `text-mode' derivatives. If set to `relative', line
   ;; numbers are relative. If set to `visual', line numbers are also relative,
   ;; but lines are only visual lines are counted. For example, folded lines
   ;; will not be counted and wrapped lines are counted as multiple lines.
   ;; This variable can also be set to a property list for finer control:
   ;; '(:relative nil
   ;;   :visual nil
   ;;   :disabled-for-modes dired-mode
   ;;                       doc-view-mode
   ;;                       markdown-mode
   ;;                       org-mode
   ;;                       pdf-view-mode
   ;;                       text-mode
   ;;   :size-limit-kb 1000)
   ;; When used in a plist, `visual' takes precedence over `relative'.
   ;; (default nil)
   dotspacemacs-line-numbers 'visual
   ;; Code folding method. Possible values are `evil' and `origami'.
   ;; (default 'evil)
   dotspacemacs-folding-method 'evil

   ;; If non-nil `smartparens-strict-mode' will be enabled in programming modes.
   ;; (default nil)
   dotspacemacs-smartparens-strict-mode nil

   ;; If non-nil pressing the closing parenthesis `)' key in insert mode passes
   ;; over any automatically added closing parenthesis, bracket, quote, etc…
   ;; This can be temporary disabled by pressing `C-q' before `)'. (default nil)
   dotspacemacs-smart-closing-parenthesis nil
   ;; Select a scope to highlight delimiters. Possible values are `any',
   ;; `current', `all' or `nil'. Default is `all' (highlight any scope and
   ;; emphasis the current one). (default 'all)
   dotspacemacs-highlight-delimiters 'all

   ;; If non-nil, start an Emacs server if one is not already running.
   dotspacemacs-enable-server t

   ;; Set the emacs server socket location.
   ;; If nil, uses whatever the Emacs default is, otherwise a directory path
   ;; like \"~/.emacs.d/server\". It has no effect if
   ;; `dotspacemacs-enable-server' is nil.
   ;; (default nil)
   dotspacemacs-server-socket-dir nil

   ;; If non-nil, advise quit functions to keep server open when quitting.
   ;; (default nil)
   dotspacemacs-persistent-server nil

   ;; List of search tool executable names. Spacemacs uses the first installed
   ;; tool of the list. Supported tools are `rg', `ag', `pt', `ack' and `grep'.
   ;; (default '("rg" "ag" "pt" "ack" "grep"))
   dotspacemacs-search-tools '("rg" "ag" "pt" "ack" "grep")

   ;; Format specification for setting the frame title.
   ;; %a - the `abbreviated-file-name', or `buffer-name'
   ;; %t - `projectile-project-name'
   ;; %I - `invocation-name'
   ;; %S - `system-name'
   ;; %U - contents of $USER
   ;; %b - buffer name
   ;; %f - visited file name
   ;; %F - frame name
   ;; %s - process status
   ;; %p - percent of buffer above top of window, or Top, Bot or All
   ;; %P - percent of buffer above bottom of window, perhaps plus Top, or Bot or All
   ;; %m - mode name
   ;; %n - Narrow if appropriate
   ;; %z - mnemonics of buffer, terminal, and keyboard coding systems
   ;; %Z - like %z, but including the end-of-line format
   ;; (default "%I@%S")
   dotspacemacs-frame-title-format "%I@%S"

   ;; Format specification for setting the icon title format
   ;; (default nil - same as frame-title-format)
   dotspacemacs-icon-title-format nil

   ;; Delete whitespace while saving buffer. Possible values are `all'
   ;; to aggressively delete empty line and long sequences of whitespace,
   ;; `trailing' to delete only the whitespace at end of lines, `changed' to
   ;; delete only whitespace for changed lines or `nil' to disable cleanup.
   ;; (default nil)
   dotspacemacs-whitespace-cleanup nil

   ;; Either nil or a number of seconds. If non-nil zone out after the specified
   ;; number of seconds. (default nil)
   dotspacemacs-zone-out-when-idle nil

   ;; Run `spacemacs/prettify-org-buffer' when
   ;; visiting README.org files of Spacemacs.
   ;; (default nil)
   dotspacemacs-pretty-docs nil))

(defun dotspacemacs/user-env ()
  "Environment variables setup.
This function defines the environment variables for your Emacs session. By
default it calls `spacemacs/load-spacemacs-env' which loads the environment
variables declared in `~/.spacemacs.env' or `~/.spacemacs.d/.spacemacs.env'.
See the header of this file for more information."
  (spacemacs/load-spacemacs-env))

(defun dotspacemacs/user-init ()
  "Initialization function for user code.
It is called immediately after `dotspacemacs/init', before layer configuration
executes.
 This function is mostly useful for variables that need to be set
before packages are loaded. If you are unsure, you should try in setting them in
`dotspacemacs/user-config' first."
  (add-hook 'org-mode-hook 'variable-pitch-mode)
  (add-hook 'org-mode-hook 'visual-line-mode)
  (add-hook 'org-mode-hook 'org-indent-mode)

  (add-hook 'company-mode-hook (lambda() (global-set-key (kbd "C-SPC") 'company-complete)))

  (add-to-list 'configuration-layer-elpa-archives '("melpa-stable" . "stable.melpa.org/packages/"))
  (add-to-list 'package-pinned-packages '(ensime . "melpa-stable"))

  (setq theming-modifications
        '((gruvbox-dark-soft
           (variable-pitch :family "ETBembo" :height 1.3 :foreground "#ebdbb2")
           (fixed-pitch :family "Iosevka" :height 1.1 :foreground "#ebdbb2")

           (org-default :inherit fixed-pitch :family "Iosevka" :weight bold :slant normal :line-spacing 0.1 :foreground "#d5c4a1")

           (header-line :inherit nil :background nil)

           (org-document-title :inherit nil :family "ETBembo" :height 2.2 :weight bold :slant normal :underline nil :foreground "#ebdbb2" )

           (org-level-1 :inherit variable-pitch :family "ETBembo" :height 1.4 :weight bold :slant normal :foreground "#f9f5d7" ) ;; bg-dark color
           (org-level-2 :inherit variable-pitch :family "ETBembo" :height 1.3 :weight bold :slant italic :foreground "#f9f5d7")
           (org-level-3 :inherit variable-pitch :family "ETBembo" :height 1.2 :weight normal :slant normal :foreground "#f9f5d7")
           (org-level-4 :inherit variable-pitch :family "ETBembo" :height 1.15 :weight normal :slant italic :foreground "#f9f5d7")
           (org-level-5 :inherit variable-pitch :family "ETBembo" :height 1.15 :weight normal :slant normal :foreground "#f9f5d7")
           (org-level-6 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant italic :foreground "#f9f5d7")
           (org-level-7 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant normal :foreground "#f9f5d7")
           (org-level-8 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant normal :foreground "#f9f5d7")

           (org-ellipsis :inherit variable-pitch :family "ETBembo" :height 1.0 :weight normal :slant normal :foreground "#d5c4a1")

           (org-document-info :height 1.2 :slant italic)
           (org-headline-done :strike-through t :family "ETBembo" :foreground "#626262")
           (org-quote :inherit variable-pitch :family "ETBembo" :height 1.0 :slant italic)
           (org-document-info-keyword :height 0.8 :foreground "#bbb") ;; grey
           (org-link :inherit nil :family "Iosevka" :foreground "royal blue")
           (org-special-keyword :family "Iosevka" :height 0.8)
           (org-agenda-current-time nil)
           (org-indent :inherit (org-hide fixed-pitch))
           (org-time-grid nil)
           (org-warning nil)
           (org-done :foreground "#afaf00")
           (org-date :family "Iosevka" :height 0.8)
           (org-agenda-structure nil)
           (org-agenda-date :inherit variable-pitch :heigh 1.1)
           (org-agenda-date-today nil)
           (org-agenda-date-weekend nil)
           (org-scheduled nil)
           (org-upcoming-deadline nil)
           (org-scheduled-today nil)
           (org-scheduled-previously nil)
           (org-agenda-done :strike-through t :foreground "#878700") ;; doc
           (org-ellipsis :underline nil :foreground "#525254") ;; comment
           (org-tag :foreground "#7c6f64") ;; doc
           (org-table :family "Iosevka" :height 0.9 :background "#282828" :foreground "#fe8019") ;; bg-white
           (org-block :background "#3c3836" :height 0.9 :family "Iosevka")
           (org-block-begin-line :background "#504945" :height 1.0 :family "Iosevka" :foreground "#7c6f64") ;; slate color
           (org-block-end-line :background "#504945" :height 1.0 :family "Iosevka" :foreground "#7c6f64")
           (org-code :family "Iosevka" :foreground "#d5c4a1" :height 0.85) ;; comment
           (hl-todo-keyword-faces
            (quote
             (("TODO" . "#a89984")
              ("INPROGRESS" . "#4f97d7")
              ("DONE" . "#a89984"))))
           (font-lock-comment-face :slant italic)
           (font-lock-type-face :slant italic)
           (font-lock-keyword-face :slant italic)
           (font-lock-builtin-face :slant italic)
           (font-lock-constant-face :slant italic)
           (default :weight light)

           )

          (gruvbox-light-medium
           (variable-pitch :family "ETBembo" :height 1.3 :foreground "#7c6f64")
           (fixed-pitch :family "Iosevka" :height 1.1 :foreground "#7c6f64")

           (org-default :inherit fixed-pitch :family "Iosevka" :weight bold :slant normal :line-spacing 0.1 :foreground "#7c6f64")

           (header-line :inherit nil :background nil)

           (org-document-title :inherit nil :family "ETBembo" :height 2.2 :weight bold :slant normal :underline nil :foreground "#504945" )

           (org-level-1 :inherit variable-pitch :family "ETBembo" :height 1.4 :weight bold :slant normal :foreground "#504945" ) ;; bg-dark color
           (org-level-2 :inherit variable-pitch :family "ETBembo" :height 1.3 :weight bold :slant italic :foreground "#504945")
           (org-level-3 :inherit variable-pitch :family "ETBembo" :height 1.2 :weight normal :slant normal :foreground "#504945")
           (org-level-4 :inherit variable-pitch :family "ETBembo" :height 1.15 :weight normal :slant italic :foreground "#504945")
           (org-level-5 :inherit variable-pitch :family "ETBembo" :height 1.15 :weight normal :slant normal :foreground "#504945")
           (org-level-6 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant italic :foreground "#504945")
           (org-level-7 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant normal :foreground "#504945")
           (org-level-8 :inherit variable-pitch :family "ETBembo" :height 1.1 :weight normal :slant normal :foreground "#504945")

           (org-ellipsis :inherit variable-pitch :family "ETBembo" :height 1.0 :weight normal :slant normal :foreground "#d5c4a1")

           (org-document-info :height 1.2 :slant italic)
           (org-headline-done :strike-through t :family "ETBembo" :foreground "#a89984")
           (org-quote :inherit variable-pitch :family "ETBembo" :height 1.0 :slant italic)
           (org-document-info-keyword :height 0.8 :foreground "#bbb") ;; grey
           (org-link :inherit nil :family "Iosevka" :foreground "royal blue")
           (org-special-keyword :family "Iosevka" :height 0.8)
           (org-agenda-current-time nil)
           (org-indent :inherit (org-hide fixed-pitch))
           (org-time-grid nil)
           (org-warning nil)
           (org-done :foreground "#afaf00")
           (org-date :family "Iosevka" :height 0.8)
           (org-agenda-structure nil)
           (org-agenda-date :inherit variable-pitch :heigh 1.1)
           (org-agenda-date-today nil)
           (org-agenda-date-weekend nil)
           (org-scheduled nil)
           (org-upcoming-deadline nil)
           (org-scheduled-today nil)
           (org-scheduled-previously nil)
           (org-agenda-done :strike-through t :foreground "#a89984") ;; doc
           (org-ellipsis :underline nil :foreground "#525254") ;; comment
           (org-tag :foreground "#7c6f64") ;; doc
           (org-table :family "Iosevka" :height 0.9 :background "#ebdbb2" :foreground "#7c6f64") ;; bg-white
           (org-block :background "#3c3836" :height 0.9 :family "Iosevka")
           (org-block-begin-line :background "#504945" :height 1.0 :family "Iosevka" :foreground "#7c6f64") ;; slate color
           (org-block-end-line :background "#504945" :height 1.0 :family "Iosevka" :foreground "#7c6f64")
           (org-code :family "Iosevka" :foreground "#282828" :height 0.85) ;; comment
           (hl-todo-keyword-faces
            (quote
             (("TODO" . "#a89984")
              ("INPROGRESS" . "#4f97d7")
              ("DONE" . "#a89984"))))
           (font-lock-comment-face :slant italic)
           (font-lock-type-face :slant italic)
           (font-lock-keyword-face :slant italic)
           (font-lock-builtin-face :slant italic)
           (font-lock-constant-face :slant italic)
           (default :weight light)
           )

          ))

  )


(defun dotspacemacs/user-config ()
  "Configuration function for user code.
This function is called at the very end of Spacemacs initialization after
layers configuration.
This is the place where most of your configurations should be done. Unless it is
explicitly specified that a variable should be set before a package is loaded,
you should place your code here."
  ;; Configuration for org-brain when using the evil mode
  (with-eval-after-load 'evil
    (evil-initial-state 'org-brain-visualize-mode 'emacs)
    )
  (with-eval-after-load 'org
    (setq org-startup-indented t
          org-src-fontify-natively t
          org-src-tab-acts-natively t
          org-fontify-whole-heading-line t
          org-fontify-done-headline t
          org-fontify-quote-and-verse-blocks t
          org-pretty-entities t
          org-hide-emphasis-markers t
          org-bullets-bullet-list '(" ")
          org-ellipsis " » "
          )
    (setq-default org-default-notes-file "~/Dropbox/org/work-todos.org")
    )
  ;; Setting up the directory for org-brain wiki
  (with-eval-after-load 'org-brain
    (setq org-brain-path "~/Dropbox/org/brain/")
    )

  (setq org-id-track-globally t
        org-id-locations-file "~/Dropbox/org/.org-id-locations"
        ;; Setting up the directory for org
        org-directory "~/Dropbox/org/"
        org-agenda-files '("~/Dropbox/org/")
        ;; Setting up the directory for org-journal
        org-journal-dir "~/Dropbox/org/journal/"
        ;; Setting up the date format for org-journal
        org-journal-file-format "%Y-%m-%d"
        org-journal-date-format "%A, %Y-%m-%d")
  (setq org-todo-keywords '((sequence "TODO" "INPROGRESS" "|" "DONE")))
  (global-company-mode)
  (setq company-dabbrev-downcase nil)
  (setq projectile-git-submodule-command nil)

  (when (boundp 'mac-auto-operator-composition-mode)
    (mac-auto-operator-composition-mode))

  (setq powerline-default-separator 'utf-8)
  (setq powerline-text-scale-factor 1.1)

  (setq exec-path (cons "/Users/rozart/.pyenv/shims" exec-path))

  (evil-leader/set-key
    "q q" 'spacemacs/frame-killer ;; Setup the quit shortcuts so they don't kill the Emacs Daemon
    "q Q" 'spacemacs/frame-killer ;; Setup the quit shortcuts so they don't kill the Emacs Daemon
    )

  )
(defun dotspacemacs/emacs-custom-settings ()
  "Emacs custom settings.
This is an auto-generated function, do not modify its content directly, use
Emacs customize menu instead.
This function is called at the very end of Spacemacs initialization."
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
)
)
