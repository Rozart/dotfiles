function claude-token-save --description 'Save a Claude subscription token outside shell history and dotfiles'
    set -l token
    if set -q CLAUDE_CODE_OAUTH_TOKEN; and test -n "$CLAUDE_CODE_OAUTH_TOKEN"
        set token "$CLAUDE_CODE_OAUTH_TOKEN"
    else
        read --silent --prompt-str 'Paste Claude token: ' token; or return 1
    end

    if not string match --quiet --regex '^[^[:space:]]+$' -- "$token"
        printf '%s\n' 'Token must be nonempty and contain no whitespace.' >&2
        return 1
    end

    set -l token_directory "$HOME/.local/share/claude-no-keychain"
    command mkdir -p -m 700 "$token_directory"; or return 1
    command chmod 700 "$token_directory"; or return 1
    set -l temporary_token (command mktemp "$token_directory/token.XXXXXX"); or return 1

    printf '%s\n' "$token" > "$temporary_token"; or begin
        command rm -f "$temporary_token"
        return 1
    end

    command mv -f "$temporary_token" "$token_directory/token"; or begin
        command rm -f "$temporary_token"
        return 1
    end

    printf '%s\n' 'Saved the Claude token privately. Future claude launches will load it automatically.'
end
