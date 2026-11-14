#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')
TEMPLATE = REPO / 'run_onchange_after_install-fleet.sh.tmpl'


def render(os, hostname):
    data = {'chezmoi': {'os': os, 'hostname': hostname}}
    return subprocess.check_output([CHEZMOI, '--source', str(REPO), '--override-data', json.dumps(data), 'execute-template', '--file', str(TEMPLATE)], text=True)


def main():
    ref = subprocess.check_output([CHEZMOI, '--source', str(REPO), 'execute-template', '{{ .fleet.install.ref }}'], text=True).strip()
    assert len(ref) == 40, ref
    for hostname in ['roz-laptop', 'roz-mini-laptop']:
        script = render('darwin', hostname)
        assert script.startswith('#!/bin/sh\n'), script[:40]
        assert f'git+ssh://homelabgit/Rozart/fleet.git@{ref}' in script
        assert 'Dev/fleet/.git' in script
    for hostname in ['roz-dev-station', 'proxmox', 'raspbox1']:
        assert not render('linux', hostname).strip()
    subprocess.run(['sh', '-n'], input=render('darwin', 'roz-laptop'), text=True, check=True)
    print('ok')


if __name__ == '__main__':
    main()
