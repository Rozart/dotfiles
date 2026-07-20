function theme --description "Switch the shared nvim/tmux/ghostty colour theme"
    # All index-matched to $slugs.
    #   ghostty_names -> theme file under ~/.config/ghostty/themes/
    #   bat_themes    -> delta's syntax-theme; must be a theme bat knows about
    #                    (`bat --list-themes`). Only Sonokai Shusia is custom.
    set -l slugs sonokai-shusia rose-pine-dawn catppuccin-latte everforest-light tokyonight-day
    set -l ghostty_names "Sonokai Shusia" "Rose Pine Dawn" "Catppuccin Latte" "Everforest Light" "Tokyo Night Day"
    set -l bat_themes sonokai-shusia GitHub GitHub gruvbox-light OneHalfLight

    set -l state ~/.config/theme

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

    # nvim and tmux read this directly at startup.
    echo $slug >$state

    # ghostty can't read an indirection at runtime, so it gets a generated
    # include (pulled in by `config-file = ?theme.conf`).
    echo "theme = \"$ghostty_names[$i]\"" >~/.config/ghostty/theme.conf

    # delta reads git config fresh on every invocation, so no reload needed.
    printf '[delta]\n  features = %s\n  syntax-theme = "%s"\n' \
        $slug $bat_themes[$i] >~/.config/delta/active.gitconfig

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

    # No CLI reloads ghostty's config; it's the reload_config keybind or restart.
    if test (uname) = Darwin
        echo "  ghostty  press cmd+shift+, to reload"
    else
        echo "  ghostty  press ctrl+shift+, to reload"
    end
end
