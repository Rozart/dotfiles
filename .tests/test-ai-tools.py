#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
CHEZMOI = shutil.which('chezmoi')
BASH = '/bin/bash'
PLANNOTATOR = '#!/bin/bash\nprintf "plannotator 0.27.25\\n"\n'
CHECKSUM = hashlib.sha256(PLANNOTATOR.encode()).hexdigest()


def render(platform, flags):
    data = {'chezmoi': {'os': platform}, 'is_dev_station': False, 'is_docker_host': False, 'is_media_host': False, **flags}
    return subprocess.check_output([CHEZMOI, '--source', str(REPO), '--override-data', json.dumps(data), 'execute-template', '--file', str(REPO / 'run_after_zz-install-ai-tools.sh.tmpl')], text=True)


def executable(directory, name, content):
    file = directory / name
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text('#!/bin/bash\n' + content)
    file.chmod(0o755)
    return file


def environment(root, platform='Linux', installed=False, brew=False):
    home = root / 'home'
    bins = root / 'bin'
    home.mkdir()
    bins.mkdir()
    log = root / 'calls'
    log.write_text('')
    env = {**os.environ, 'HOME': str(home), 'PATH': f'{bins}:/usr/bin:/bin', 'CALL_LOG': str(log), 'STUB_BIN': str(bins), 'HOST_OS': platform, 'TMPDIR': str(root), 'BAD_CHECKSUM': '0', 'FAIL_ATTESTATION': '0'}
    executable(bins, 'uname', 'if [ "${1:-}" = -m ]; then echo arm64; else echo "$HOST_OS"; fi\n')
    executable(bins, 'curl', '''printf 'curl:%s\\n' "$*" >> "$CALL_LOG"
url=""; output=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        https://*) url="$1" ;;
        --output) shift; output="$1" ;;
    esac
    shift
done
case "$url" in
    https://pi.dev/install.sh)
        printf '%s\\n' '#!/bin/bash' 'mkdir -p "$HOME/.pi/agent/bin"' 'printf "#!/bin/bash\\nprintf pi:%%s\\\\n \\\"\\$*\\\" >> \\\"\\$CALL_LOG\\\"\\n" > "$HOME/.pi/agent/bin/pi"' 'chmod 755 "$HOME/.pi/agent/bin/pi"' > "$output"
        ;;
    https://claude.ai/install.sh)
        printf '%s\\n' '#!/bin/bash' 'printf "claude-install:%s:%s\\n" "$1" "$DISABLE_AUTOUPDATER" >> "$CALL_LOG"' 'mkdir -p "$HOME/.local/bin"' 'printf "#!/bin/bash\\nprintf claude:%%s\\\\n \\\"\\$*\\\" >> \\\"\\$CALL_LOG\\\"\\n" > "$HOME/.local/bin/claude"' 'chmod 755 "$HOME/.local/bin/claude"' > "$output"
        ;;
    *.sha256)
        if [ "$BAD_CHECKSUM" = 1 ]; then printf '%064d\\n' 0 > "$output"; else echo "$EXPECTED_CHECKSUM" > "$output"; fi
        ;;
    */plannotator-*) printf '#!/bin/bash\\nprintf "plannotator 0.27.25\\\\n"\\n' > "$output" ;;
    *) exit 91 ;;
esac
''')
    env['EXPECTED_CHECKSUM'] = CHECKSUM
    executable(bins, 'node', 'exit 0\n')
    executable(bins, 'npm', 'exit 0\n')
    executable(bins, 'gh', 'printf "gh:%s\\n" "$*" >> "$CALL_LOG"\nexit "$FAIL_ATTESTATION"\n')
    if installed:
        executable(home / '.pi/agent/bin', 'pi', 'printf "pi:%s\\n" "$*" >> "$CALL_LOG"\n')
        executable(home / '.local/bin', 'claude', 'printf "claude:%s\\n" "$*" >> "$CALL_LOG"\n')
        executable(home / '.local/bin', 'plannotator', 'printf "plannotator 0.27.25\\n"\n')
    if brew:
        executable(bins, 'brew', '''printf 'brew:%s\\n' "$*" >> "$CALL_LOG"
if [ "$1" = list ]; then exit 0; fi
if [ "$1" = install ]; then
    printf '#!/bin/bash\\nexit 0\\n' > "$STUB_BIN/claude"
    chmod 755 "$STUB_BIN/claude"
fi
''')
    return env, home, log


def run_install(root, script, **options):
    env, home, log = environment(root, **options)
    file = root / 'installer.sh'
    file.write_text(script)
    result = subprocess.run([BASH, str(file)], env=env, capture_output=True, text=True)
    return result, env, home, log


def main():
    mac = render('darwin', {})
    linux = render('linux', {'is_dev_station': True})
    assert 'brew install --cask claude-code' in mac
    assert 'bash "$stage/claude-install.sh" stable' in linux
    for flag in ['is_dev_station', 'is_docker_host', 'is_media_host']:
        assert render('linux', {flag: True}).strip()
    assert not render('linux', {}).strip()
    assert not render('windows', {'is_dev_station': True}).strip()
    subprocess.run([BASH, '-n'], input=mac, text=True, check=True)
    subprocess.run([BASH, '-n'], input=linux, text=True, check=True)
    subprocess.run([BASH, '-n', str(REPO / 'dot_local/bin/executable_update-all')], check=True)
    with tempfile.TemporaryDirectory(prefix='chezmoi-ai-tests-') as directory:
        root = Path(directory)
        for name in ['noop', 'linux', 'mac', 'checksum', 'attestation', 'mismatch', 'updates-linux', 'updates-mac', 'mise']:
            (root / name).mkdir()
        result, env, home, log = run_install(root / 'noop', linux, installed=True)
        assert result.returncode == 0, result.stderr
        assert not log.read_text()
        result, env, home, log = run_install(root / 'linux', linux)
        assert result.returncode == 0, result.stderr
        assert 'claude-install:stable:1' in log.read_text()
        assert (home / '.local/bin/plannotator').read_text() == PLANNOTATOR
        assert not list((root / 'linux').glob('chezmoi-ai-tools.*'))
        previous = log.read_text()
        second = subprocess.run([BASH, str(root / 'linux/installer.sh')], env=env, capture_output=True, text=True)
        assert second.returncode == 0, second.stderr
        assert log.read_text() == previous
        mise_env, mise_home, mise_log = environment(root / 'mise')
        executable(root / 'mise/bin', 'mise', 'printf "mise:%s\\n" "$*" >> "$CALL_LOG"\nshift 5\nexec "$@"\n')
        mise_script = root / 'mise/installer.sh'
        mise_script.write_text(linux)
        mise_result = subprocess.run([BASH, str(mise_script)], env=mise_env, capture_output=True, text=True)
        assert mise_result.returncode == 0, mise_result.stderr
        assert f'mise:--cd {mise_home} exec node -- sh' in mise_log.read_text()
        result, env, home, log = run_install(root / 'mac', mac, platform='Darwin', brew=True)
        assert result.returncode == 0, result.stderr
        assert 'brew:install --cask claude-code' in log.read_text()
        assert 'claude-install:' not in log.read_text()
        for name, setting in [('checksum', 'BAD_CHECKSUM'), ('attestation', 'FAIL_ATTESTATION')]:
            env, home, log = environment(root / name)
            env[setting] = '1'
            file = root / name / 'installer.sh'
            file.write_text(linux)
            result = subprocess.run([BASH, str(file)], env=env, capture_output=True, text=True)
            assert result.returncode != 0
            assert not (home / '.local/bin/plannotator').exists()
        env, home, log = environment(root / 'mismatch', installed=True)
        executable(home / '.local/bin', 'plannotator', 'printf "plannotator 0.26.0\\n"\n')
        file = root / 'mismatch/installer.sh'
        file.write_text(linux)
        result = subprocess.run([BASH, str(file)], env=env, capture_output=True, text=True)
        assert result.returncode != 0
        assert '0.26.0' in (home / '.local/bin/plannotator').read_text()
        updater = str(REPO / 'dot_local/bin/executable_update-all')
        for name, platform, brew in [('updates-linux', 'Linux', False), ('updates-mac', 'Darwin', True)]:
            env, home, log = environment(root / name, platform=platform, installed=True, brew=brew)
            listing = subprocess.check_output([BASH, updater, '--list'], env=env, text=True)
            assert 'Pi (latest stable)' in listing
            assert ('Claude Code (stable)' in listing) == (not brew)
            result = subprocess.run([BASH, updater, '--all'], env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            assert 'pi:update --self --no-approve' in log.read_text()
            assert ('claude:update' in log.read_text()) == (not brew)
    print('ok — host scope, missing installs, idempotence, checksum/provenance failures, version mismatch, update ownership')


if __name__ == '__main__':
    main()
