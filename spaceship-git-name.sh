SPACESHIP_GIT_USER_SHOW="${SPACESHIP_GIT_USER_SHOW=true}"
SPACESHIP_GIT_USER_PREFIX="${SPACESHIP_GIT_USER_PREFIX="as "}"
SPACESHIP_GIT_USER_SYMBOL="${SPACESHIP_GIT_USER_SYMBOL=" "}"
SPACESHIP_GIT_EMAIL_SYMBOL="${SPACESHIP_GIT_EMAIL_SYMBOL=" "}"
SPACESHIP_GIT_USER_COLOR="${SPACESHIP_GIT_USER_COLOR="red"}"

spaceship_git_user() {
    [[ $SPACESHIP_GIT_USER_SHOW == false ]] && return

    spaceship::is_git || return

    local section=""
    local username="$(git config user.name)"
    local email="$(git config user.email)"

    if [[ -n $username ]]; then
        section+="$SPACESHIP_GIT_USER_SYMBOL$username "
    fi

    if [[ -n $email ]]; then
        section+="[$email] "
    fi

    if [[ -n $section ]]; then
        spaceship::section::v4 \
            --color "$SPACESHIP_GIT_USER_COLOR" \
            --prefix "$SPACESHIP_GIT_USER_PREFIX" \
            "$section"
    fi
}
