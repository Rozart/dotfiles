#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')

EXPECTED = {
    ('darwin', 'roz-laptop'): ['mac'],
    ('darwin', 'laptop'): ['mac'],
    ('darwin', 'ROZ-MINI-LAPTOP'): ['mac'],
    ('linux', 'roz-dev-station'): ['homelab'],
    ('linux', 'roz-docker-host'): ['homelab'],
    ('linux', 'roz-media-host'): ['homelab'],
    ('linux', 'proxmox'): ['infra'],
    ('linux', 'raspbox1'): ['pi'],
    ('linux', 'raspbox2'): ['pi'],
    ('linux', 'unknown-box'): [],
    ('darwin', 'unknown-mac'): [],
    ('linux', 'roz-laptop'): [],
}


def execute(template, os, hostname):
    data = {'chezmoi': {'os': os, 'hostname': hostname}}
    return subprocess.check_output([CHEZMOI, '--source', str(REPO), '--override-data', json.dumps(data), 'execute-template', template], text=True)


def main():
    for (os, hostname), roles in EXPECTED.items():
        rendered = execute('{{ includeTemplate "host-roles" . }}', os, hostname)
        assert json.loads(rendered) == roles, f'{os}/{hostname}: {rendered!r}'
    samba = (REPO / 'run_onchange_after_setup-samba-server.sh.tmpl').read_text()
    for hostname in ['roz-dev-station', 'roz-docker-host', 'roz-media-host']:
        assert execute(samba, 'linux', hostname).strip()
    for os, hostname in [('linux', 'proxmox'), ('linux', 'raspbox1'), ('darwin', 'roz-laptop')]:
        assert not execute(samba, os, hostname).strip()
    print('ok')


if __name__ == '__main__':
    main()
