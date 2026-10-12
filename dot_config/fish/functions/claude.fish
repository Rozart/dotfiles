function claude --description 'Run Claude without its macOS Keychain helper calls'
    if test (command uname) != Darwin
        command claude $argv
        return $status
    end

    set -l helper_directory "$HOME/.local/lib/claude-no-keychain"
    if not test -x "$helper_directory/security"
        printf '%s\n' 'Claude Keychain helper is missing. Reapply the Claude fish configuration.' >&2
        return 1
    end
    set -lx PATH "$helper_directory" $PATH

    if test (count $argv) -gt 0; and contains -- "$argv[1]" setup-token --help -h --version -v
        command claude $argv
        return $status
    end

    set -lx CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE_CODE_OAUTH_TOKEN"
    set -l token_path "$HOME/.local/share/claude-no-keychain/token"
    if test -r "$token_path"
        set -l token
        read token < "$token_path"
        if not string match --quiet --regex '^[^[:space:]]+$' -- "$token"
            printf '%s\n' 'Claude token file is empty or invalid. Run claude-token-save.' >&2
            return 1
        end
        set CLAUDE_CODE_OAUTH_TOKEN "$token"
    else if not set -q CLAUDE_CODE_OAUTH_TOKEN; or test -z "$CLAUDE_CODE_OAUTH_TOKEN"
        printf '%s\n' 'Run claude setup-token, then claude-token-save once to save the token privately.' >&2
        return 1
    end

    command claude $argv
end
