function theme --description "Switch the shared nvim/tmux/ghostty/bat/btop/delta/claude colour theme"
    # ponytail: three index-matched lists plus per-app files found by name. A new
    # theme means re-typing the same palette in six incompatible formats (~85 hex
    # values) with nothing checking they agree. Upgrade path when that starts
    # hurting: one .chezmoidata/themes.toml palette per slug plus chezmoi
    # templates generating every consumer — .chezmoitemplates/tmuxline.tmux.conf
    # already proves the pattern. Not before.
    #
    # All index-matched to $slugs.
    #   ghostty_names -> theme file under ~/.config/ghostty/themes/, or a builtin
    #   bat_themes    -> BAT_THEME and delta's syntax-theme; must be a theme bat
    #                    knows about (`bat --list-themes`).
    set -l slugs sonokai-shusia sonokai-hikari rose-pine-dawn catppuccin-latte \
        everforest-light tokyonight-day gruvbox-material-dark gruvbox-material-light
    set -l ghostty_names "Sonokai Shusia" "Sonokai Hikari" "Rose Pine Dawn" "Catppuccin Latte" \
        "Everforest Light" "Tokyo Night Day" "Gruvbox Material Dark" "Gruvbox Material Light"
    set -l bat_themes sonokai-shusia "Monokai Extended Light" GitHub GitHub \
        gruvbox-light OneHalfLight gruvbox-dark gruvbox-light

    set -l state ~/.config/theme

    if contains -- --list $argv
        printf '%s\n' $slugs
        return 0
    end

    if test (count $argv) -eq 0
        if test -f $state
            cat $state
        else
            echo sonokai-shusia
        end
        return 0
    end

    set -l slug $argv[1]
    set -l i (contains -i -- $slug $slugs)

    if test -z "$i"
        echo "theme: unknown theme '$slug'" >&2
        echo "available:" >&2
        printf '  %s\n' $slugs >&2
        return 1
    end

    # Fail before writing anything: a dropped list entry silently shifts every
    # theme after it, and a missing asset leaves tmux on one theme and delta on
    # another. ghostty and bat take builtin names that can't be stat'd, so a typo
    # there still falls back quietly — the gap we keep.
    if test (count $ghostty_names) -ne (count $slugs) -o (count $bat_themes) -ne (count $slugs)
        echo "theme: list length mismatch in theme.fish" >&2
        return 1
    end

    for f in ~/.config/tmux/tmuxline/$slug.tmux.conf ~/.config/delta/themes/$slug.gitconfig \
        ~/.config/claude-code/themes/$slug.json ~/.config/btop/themes/$slug.theme
        if not test -f $f
            echo "theme: $slug is missing $f" >&2
            return 1
        end
    end

    # nvim and tmux read this directly at startup.
    echo $slug >$state

    # ghostty can't read an indirection at runtime, so it gets a generated
    # include (pulled in by `config-file = ?theme.conf`).
    echo "theme = \"$ghostty_names[$i]\"" >~/.config/ghostty/theme.conf

    # delta reads git config fresh on every invocation, so no reload needed.
    printf '[delta]\n  features = %s\n  syntax-theme = "%s"\n' \
        $slug $bat_themes[$i] >~/.config/delta/active.gitconfig

    # bat has no config indirection, but it reads BAT_THEME. Universal, so it
    # persists and lands in every running fish shell at once. No cache rebuild:
    # the cache compiles ~/.config/bat/themes and we add nothing to it.
    set -Ux BAT_THEME $bat_themes[$i]

    # btop names one theme in its config and rewrites that config on exit, so the
    # name stays put and the file behind it is what changes.
    cp ~/.config/btop/themes/$slug.theme ~/.config/btop/themes/active.theme

    # claude code is pinned to `theme = "custom:system"`, so only the file
    # contents change. It watches ~/.claude/themes/ and reloads live.
    mkdir -p ~/.claude/themes
    cp ~/.config/claude-code/themes/$slug.json ~/.claude/themes/system.json

    set_color --bold
    echo "$slug"
    set_color normal

    if tmux has-session 2>/dev/null
        tmux source-file ~/.config/tmux/tmux.conf >/dev/null 2>&1
        echo "  tmux     reloaded"
    else
        echo "  tmux     no server running"
    end

    echo "  nvim     next launch"
    echo "  git      delta follows immediately"
    echo "  bat      follows immediately"
    echo "  btop     next launch"
    echo "  claude   reloaded"
    # fish needs no line here: it queries the terminal background itself and
    # picks the matching variant of ~/.config/fish/themes/ansi.theme.

    # No CLI reloads ghostty's config; it's the reload_config keybind or restart.
    if test (uname) = Darwin
        echo "  ghostty  press cmd+shift+, to reload"
    else
        echo "  ghostty  press ctrl+shift+, to reload"
    end
end
