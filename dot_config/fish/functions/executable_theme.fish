function theme --description "Switch the shared colour theme across every app that follows it"
    # ponytail: five index-matched lists plus per-app files found by name. The
    # accent hex now lives in three places per slug — the tmuxline manifest, the
    # claude-code json, and $accents here — with nothing checking they agree.
    # That, not the file count, is what will break first. Upgrade path unchanged:
    # one .chezmoidata/themes.toml per slug plus chezmoi templates generating
    # every consumer, which .chezmoitemplates/tmuxline.tmux.conf already proves.
    # Do it when a switch first shows mismatched colours, not before.
    #
    # All index-matched to $slugs.
    #   ghostty_names -> theme file under ~/.config/ghostty/themes/, or a builtin
    #   bat_themes    -> BAT_THEME and delta's syntax-theme; must be a theme bat
    #                    knows about (`bat --list-themes`).
    #   dark          -> 1 for a dark theme. Drives macOS system appearance, which
    #                    is the only lever Brave/Slack/Beeper/Spotify respond to.
    #   accents       -> the theme's accent, same value the tmuxline manifest and
    #                    the claude-code json carry. Window borders.
    #   cursors       -> ghostty's cursor and its smear-trail shader. A locator,
    #                    not a palette colour: picked for maximum luminance
    #                    distance from the paper (all >=7:1) in a hue that theme
    #                    has no accent near, so it reads as the cursor rather
    #                    than as syntax. Light papers can only hold a saturated
    #                    colour that dark in the blue-violet-magenta arc, which
    #                    is why six of them live there.
    set -l slugs sonokai-shusia sonokai-hikari rose-pine-dawn catppuccin-latte \
        everforest-light tokyonight-day gruvbox-material-dark gruvbox-material-light
    set -l ghostty_names "Sonokai Shusia" "Sonokai Hikari" "Rose Pine Dawn" "Catppuccin Latte" \
        "Everforest Light" "Tokyo Night Day" "Gruvbox Material Dark" "Gruvbox Material Light"
    set -l bat_themes sonokai-shusia "Monokai Extended Light" GitHub GitHub \
        gruvbox-light OneHalfLight gruvbox-dark gruvbox-light
    set -l dark 1 0 0 0 0 0 1 0
    set -l accents "#78dce8" "#0d7f9b" "#286983" "#1e66f5" \
        "#3a94c5" "#2e7de9" "#7daea3" "#45707a"
    set -l cursors "#03fc07" "#8a00a4" "#1b1bd0" "#84009e" \
        "#5606c4" "#7c008f" "#00ffff" "#1c1ccf"

    set -l state ~/.config/theme

    # LAN boxes that follow this Mac. These are ssh aliases, not hostnames — the
    # machines call themselves roz-*.
    # ponytail: hardcoded in two files now (hosts-tabs has the same three). A
    # third copy earns a .chezmoitemplates entry.
    set -l remote_hosts dev-station docker-host media-host

    # Loop prevention, and the flag is the weakest of the three layers. The
    # load-bearing one is this uname test: a remote run is Linux, so it empties
    # the list before it ever looks at argv. Backstop: the LAN block in
    # private_dot_ssh/config.tmpl is wrapped in `if eq .chezmoi.os "darwin"`, so
    # `ssh dev-station` on a box resolves to nothing at all.
    test (uname) = Darwin; or set remote_hosts
    set -l local_flag (contains -i -- --local $argv)
    if test -n "$local_flag"
        set -e argv[$local_flag]
        set remote_hosts
    end

    if contains -- --list $argv
        printf '%s\n' $slugs
        return 0
    end

    if contains -- --slack $argv
        # Slack's sidebar theme is a server-side account preference — see
        # ~/.config/slack/themes/README.md for why it can't be written to disk.
        # Its own subcommand rather than part of a switch: pasting into Slack is
        # a manual step anyway, and hijacking the clipboard on every `theme` call
        # to save one command would be rude.
        set -l cur (theme)
        if not test -f ~/.config/slack/themes/$cur.txt
            echo "theme: no slack payload for '$cur'" >&2
            return 1
        end
        pbcopy <~/.config/slack/themes/$cur.txt
        echo "$cur copied — paste into Slack → Preferences → Themes → Create a custom theme"
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
    if test (count $ghostty_names) -ne (count $slugs) \
            -o (count $bat_themes) -ne (count $slugs) \
            -o (count $dark) -ne (count $slugs) \
            -o (count $accents) -ne (count $slugs) \
            -o (count $cursors) -ne (count $slugs)
        echo "theme: list length mismatch in theme.fish" >&2
        return 1
    end

    set -l required ~/.config/tmux/tmuxline/$slug.tmux.conf ~/.config/delta/themes/$slug.gitconfig \
        ~/.config/claude-code/themes/$slug.json ~/.config/btop/themes/$slug.theme
    # Beeper and Slack are Mac-only apps; the Linux boxes must not fail a switch
    # over assets they have no use for.
    if test (uname) = Darwin
        set -a required ~/.config/beeper/palettes/$slug.css ~/.config/slack/themes/$slug.txt
    end
    for f in $required
        if not test -f $f
            echo "theme: $slug is missing $f" >&2
            return 1
        end
    end

    # Fired before the local writes so three round-trips overlap them and each
    # other. Output goes to files, never the terminal: jobs finish out of order
    # and the report below wants one line per host in list order.
    #
    # None of these -o flags are optional. All three Host blocks set
    # `RemoteCommand tmux new-session -A -s <host>`, and ssh refuses to run a
    # command line alongside a RemoteCommand ("Cannot execute command-line and
    # remote command.", exit 255) — RemoteCommand=none is what makes this
    # possible at all. -T undoes their `RequestTTY yes`. ClearAllForwardings
    # drops eleven LocalForwards and the two RemoteForwards that the live
    # interactive sessions own, so a switch can't disturb the clipboard tunnel.
    # LogLevel=ERROR undoes their `LogLevel QUIET`, or a rejected key says
    # nothing. ConnectTimeout has no default and macOS ships no timeout(1), so
    # without it a dead host hangs forever.
    set -l fanout
    if set -q remote_hosts[1]
        set fanout (mktemp -d)
        for h in $remote_hosts
            begin
                ssh -n -T -a \
                    -o RemoteCommand=none \
                    -o ClearAllForwardings=yes \
                    -o BatchMode=yes \
                    -o ConnectTimeout=3 \
                    -o ServerAliveInterval=3 \
                    -o ServerAliveCountMax=2 \
                    -o LogLevel=ERROR \
                    $h "fish -c 'theme $slug --local'" >/dev/null 2>$fanout/$h.err
                echo $status >$fanout/$h.rc
            end &
        end
    end

    # nvim and tmux read this directly at startup.
    echo $slug >$state

    # ghostty can't read an indirection at runtime, so it gets a generated
    # include (pulled in by `config-file = ?theme.conf`). It carries the cursor
    # too: the cursor is a locator, so it wants the opposite of the theme's own
    # low-contrast cursor-color.
    printf 'theme = "%s"\ncursor-color = "%s"\n' \
        $ghostty_names[$i] $cursors[$i] >~/.config/ghostty/theme.conf

    # The smear-trail shader bakes its colour in as a GLSL constant rather than
    # reading cursor-color, so the active shader is generated per theme. Only
    # that one line differs from the source.
    if test (uname) = Darwin
        set -l shader_src ~/.config/ghostty/shaders/cursor_smear_fade.glsl
        set -l hex (string sub -s 2 $cursors[$i])
        set -l r (printf '%.3f' (math 0x(string sub -s 1 -l 2 $hex)/255))
        set -l g (printf '%.3f' (math 0x(string sub -s 3 -l 2 $hex)/255))
        set -l b (printf '%.3f' (math 0x(string sub -s 5 -l 2 $hex)/255))
        string replace -r '^const vec4 TRAIL_COLOR = vec4\(.*\);' \
            "const vec4 TRAIL_COLOR = vec4($r, $g, $b, 1.0);" \
            <$shader_src >~/.config/ghostty/shaders/active.glsl
        echo "custom-shader = shaders/active.glsl" >>~/.config/ghostty/theme.conf
    end

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

    # borders reads bordersrc on a cold start; a running instance takes the same
    # args directly. 0xAARRGGBB — alpha FIRST (`man borders`). One neutral grey
    # for inactive across every theme: it is deliberately low-contrast and reads
    # on both polarities.
    # ponytail: one grey. Per-theme inactive if a light theme ever looks wrong.
    if command -q borders
        set -l border_args "active_color=0xe4"(string sub -s 2 $accents[$i]) \
            inactive_color=0x647f8490 width=5.0
        mkdir -p ~/.config/borders
        printf '#!/bin/sh\nborders %s\n' "$border_args" >~/.config/borders/bordersrc
        chmod +x ~/.config/borders/bordersrc
        borders $border_args >/dev/null 2>&1
    end

    if test (uname) = Darwin
        # Beeper injects this file as a <style> tag. The palette must come first:
        # base.css consumes the --th-* roles it defines.
        set -l beeper ~/Library/Application\ Support/BeeperTexts
        if test -d $beeper
            cat ~/.config/beeper/palettes/$slug.css ~/.config/beeper/base.css >$beeper/custom.css
        end

        # osascript, not `defaults write`: only this posts the change
        # notification that makes running apps actually repaint. Backgrounded
        # because it can take a moment, and the first ever call raises a TCC
        # prompt that must be accepted once.
        set -l mode false
        test $dark[$i] -eq 1; and set mode true
        osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $mode" \
            >/dev/null 2>&1 &
        disown
    end

    set_color --bold
    echo "$slug"
    set_color normal

    if tmux has-session 2>/dev/null
        tmux source-file ~/.config/tmux/tmux.conf >/dev/null 2>&1
        echo "  tmux     reloaded"
    else
        echo "  tmux     no server running"
    end

    # Every live nvim, over its own socket. Stale sockets outlive their processes,
    # so filter by liveness. An instance sitting at a hit-enter prompt blocks the
    # RPC forever and macOS ships no timeout(1), so every call is backgrounded.
    set -l reloaded 0
    for sock in (find $TMPDIR/nvim.$USER -maxdepth 2 -name 'nvim.*.0' 2>/dev/null)
        set -l pid (string replace -rf '.*/nvim\.(\d+)\.0$' '$1' $sock)
        kill -0 $pid 2>/dev/null; or continue
        command nvim --server $sock --remote-expr 'luaeval("require\"config.palettes\".apply()")' \
            >/dev/null 2>&1 &
        disown
        set reloaded (math $reloaded + 1)
    end
    if test $reloaded -gt 0
        echo "  nvim     $reloaded instance(s) reloaded"
    else
        echo "  nvim     none running"
    end

    echo "  git      delta follows immediately"
    echo "  bat      follows immediately"
    echo "  claude   reloaded"
    # fish needs no line here: it queries the terminal background itself and
    # picks the matching variant of ~/.config/fish/themes/ansi.theme.

    # btop hot-reloads its config on SIGUSR2 (documented in its CHANGELOG).
    if pkill -USR2 -x btop 2>/dev/null
        echo "  btop     reloaded"
    else
        echo "  btop     not running"
    end

    if test (uname) = Darwin
        command -q borders; and echo "  borders  reloaded"
        test -d ~/Library/Application\ Support/BeeperTexts; and echo "  beeper   custom.css written"
        echo "  macos    appearance set"
        echo "  slack    theme --slack to copy"
    end

    # ghostty reloads config on SIGUSR2. Undocumented — the binary carries
    # "reloading configuration in response to SIGUSR2" — and there is no
    # +reload-config among the actions `ghostty +help` lists.
    if pkill -USR2 -x ghostty 2>/dev/null
        echo "  ghostty  reloaded"
    else
        echo "  ghostty  not running"
    end

    if set -q fanout[1]
        wait
        for h in $remote_hosts
            set -l rc (cat $fanout/$h.rc)
            # Grep the whole file, not just line one: ssh prints key warnings
            # ahead of the verdict, and misreading a rejected key as "offline"
            # sends you debugging the wrong machine.
            set -l denied (grep -m1 'Permission denied' $fanout/$h.err)
            # Trailing element only exists so index 1 stays valid when a failure
            # wrote nothing to stderr at all.
            set -l why (head -n 1 $fanout/$h.err) "exit status $rc"
            if test $rc -eq 0
                set why ok
            else if test -n "$denied"
                set why $denied
            else if test $rc -eq 255
                # Off the LAN, powered down, sshd dead: the quiet skip.
                set why offline
            end
            printf '  %-12s %s\n' $h $why[1]
        end
        rm -rf $fanout
    end
end
