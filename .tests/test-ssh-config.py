#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')


def rendered_config():
    return subprocess.check_output([CHEZMOI, '--source', str(REPO), 'execute-template', '--file', str(REPO / 'private_dot_ssh/config.tmpl')], text=True)


def identity_agent(config, rex_session):
    env = {key: value for key, value in os.environ.items() if key != 'REX_SESSION'}
    if rex_session:
        env['REX_SESSION'] = rex_session
    output = subprocess.check_output(['ssh', '-F', str(config), '-G', 'fleet-test-host'], env=env, stderr=subprocess.DEVNULL, text=True)
    return next((line.split(' ', 1)[1] for line in output.splitlines() if line.startswith('identityagent ')), None)


def main():
    config = rendered_config()
    for line in config.splitlines():
        if line.lstrip().startswith('Match exec'):
            assert not re.search(r'\\"', line), f'OpenSSH 9.6 cannot parse escaped quotes in Match exec: {line}'
    with tempfile.TemporaryDirectory(prefix='chezmoi-ssh-tests-') as directory:
        file = Path(directory) / 'config'
        file.write_text(config.replace('Include ~/.ssh/config.d/*.conf', ''))
        assert identity_agent(file, 'session:test') == 'SSH_AUTH_SOCK'
        assert identity_agent(file, None) != 'SSH_AUTH_SOCK'
    print('ok')


if __name__ == '__main__':
    main()
