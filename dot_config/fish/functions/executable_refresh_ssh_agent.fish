function refresh_ssh_agent --description 'Refresh the SSH agent for Rex or tmux'
    if set -q REX_SESSION; and test (uname) = Linux
        set -gx SSH_AUTH_SOCK /run/user/(id -u)/rex-ssh-agent/agent.sock
    else if set -q TMUX
        set -l live_socket (tmux show-env SSH_AUTH_SOCK 2>/dev/null | cut -d'=' -f2)
        if test -n "$live_socket"
            set -gx SSH_AUTH_SOCK $live_socket
        end
    end
end
