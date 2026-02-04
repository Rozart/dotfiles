function refresh_ssh_agent --description 'Refresh SSH agent socket within TMUX'
    if set -q TMUX
        set -l live_socket (tmux show-env SSH_AUTH_SOCK 2>/dev/null | cut -d'=' -f2)
        if test -n "$live_socket"
            set -gx SSH_AUTH_SOCK $live_socket
        end
    end
end
