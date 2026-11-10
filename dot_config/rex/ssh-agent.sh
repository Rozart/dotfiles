if [ -n "${REX_SESSION:-}" ]; then
    SSH_AUTH_SOCK="$HOME/.local/state/rex/ssh-agent/unrouted.sock"
    case "${REX_BLOCK:-}" in
        block:????????-????-????-????-????????????)
            rex_agent_block=${REX_BLOCK#block:}
            case "$rex_agent_block" in
                *[!0-9a-f-]*) ;;
                *) SSH_AUTH_SOCK="$HOME/.local/state/rex/ssh-agent/b-$rex_agent_block.sock" ;;
            esac
            unset rex_agent_block
            ;;
    esac
    export SSH_AUTH_SOCK
fi
