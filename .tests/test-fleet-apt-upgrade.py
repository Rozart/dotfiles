#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')
SCRIPT = REPO / 'run_onchange_after_setup-fleet-apt-upgrade.sh.tmpl'
WRAPPER = REPO / '.chezmoitemplates/fleet-apt-upgrade.sh'


def render(os_name, hostname):
    data = {'chezmoi': {'os': os_name, 'hostname': hostname, 'username': 'rozart'}}
    return subprocess.check_output([CHEZMOI, '--source', str(REPO), '--override-data', json.dumps(data), 'execute-template', '--file', str(SCRIPT)], text=True)


def run_wrapper(stub_dir, log, *packages):
    env = {**os.environ, 'PATH': f'{stub_dir}:/usr/bin:/bin', 'CALL_LOG': str(log)}
    return subprocess.run(['sh', str(WRAPPER), *packages], env=env, capture_output=True, text=True)


def main():
    for hostname in ['roz-dev-station', 'roz-docker-host', 'roz-media-host']:
        script = render('linux', hostname)
        assert 'visudo -cf' in script and '/usr/local/sbin/fleet-apt-upgrade' in script, script[:200]
        assert """printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/fleet-apt-upgrade\\n' "rozart" >""" in script
        assert WRAPPER.read_text().strip().splitlines()[-1] in script
        subprocess.run(['sh', '-n'], input=script, text=True, check=True)
    for os_name, hostname in [('darwin', 'roz-laptop'), ('linux', 'proxmox'), ('linux', 'raspbox1')]:
        assert not render(os_name, hostname).strip(), hostname

    with tempfile.TemporaryDirectory(prefix='fleet-apt-') as directory:
        stub_dir, log = Path(directory), Path(directory) / 'calls'
        stub = stub_dir / 'apt-get'
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALL_LOG"\n')
        stub.chmod(0o755)
        ok = run_wrapper(stub_dir, log, 'ripgrep', 'docker-ce', 'libc6', 'g++-13')
        assert ok.returncode == 0, ok.stderr
        assert log.read_text().splitlines() == ['update -qq', 'install -y --only-upgrade -o Dpkg::Options::=--force-confold ripgrep docker-ce libc6 g++-13']
        log.unlink()
        for bad in (['-o', 'Dpkg::Pre-Invoke::=id'], ['ripgrep;id'], ['Ripgrep'], [''], ['a b'], []):
            refused = run_wrapper(stub_dir, log, *bad)
            assert refused.returncode == 2 and not log.exists(), (bad, refused.stderr)
    print('ok')


if __name__ == '__main__':
    main()
