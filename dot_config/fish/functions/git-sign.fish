function git-sign --description "Sign last N commits"
    if test (count $argv) -eq 0
        echo "Usage: git-sign <number>"
        return 1
    end
    git rebase HEAD~$argv[1] --exec "git commit --amend --no-edit -S"
end
