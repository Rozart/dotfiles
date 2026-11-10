import sys

content = sys.stdin.read()
line = 'if [ -n "${REX_SESSION:-}" ]; then . "$HOME/.config/rex/ssh-agent.sh"; fi'
if line not in content.splitlines():
    content = line + "\n" + content
sys.stdout.write(content)
