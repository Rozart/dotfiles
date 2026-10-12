#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
FUNCTIONS = REPO / 'dot_config/fish/functions'
LAUNCHER = FUNCTIONS / 'claude.fish'
SAVER = FUNCTIONS / 'claude-token-save.fish'
HELPER = REPO / 'dot_local/lib/claude-no-keychain/executable_security'
FISH = shutil.which('fish')
TOKEN = 'test-only-subscription-token'


class ClaudeNoKeychainTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'home'
        self.bins = self.root / 'bin'
        self.home.mkdir()
        self.bins.mkdir()
        self.helper = self.home / '.local/lib/claude-no-keychain/security'
        self.helper.parent.mkdir(parents=True)
        shutil.copyfile(HELPER, self.helper)
        self.helper.chmod(0o755)
        self.token_file = self.home / '.local/share/claude-no-keychain/token'
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(('CLAUDE_', 'ANTHROPIC_'))
        }
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'), XDG_DATA_HOME=str(self.home / '.local/share'), PATH=f'{self.bins}:/usr/bin:/bin', HOST_OS='Darwin', EXPECTED_TOKEN=TOKEN)
        self.executable('uname', '#!/bin/sh\nprintf "%s\\n" "$HOST_OS"\n')
        self.executable('claude', f'''#!{shutil.which('python3')}
import json
import os
import shutil
import subprocess
import sys
helper = shutil.which('security')
checks = []
if helper and helper.startswith(os.environ['HOME']):
    for service in ['Claude Code-credentials', 'Claude Code']:
        checks.append(subprocess.run(['security', 'find-generic-password', '-a', 'test-user', '-w', '-s', service], capture_output=True).returncode)
print(json.dumps({{'args': sys.argv[1:], 'token_matches': os.environ.get('CLAUDE_CODE_OAUTH_TOKEN') == os.environ['EXPECTED_TOKEN'], 'helper': helper, 'lookup_codes': checks}}))
sys.exit(int(os.environ.get('CLAUDE_TEST_EXIT', '0')))
''')

    def executable(self, name, text):
        path = self.bins / name
        path.write_text(text)
        path.chmod(0o755)

    def run_fish(self, code, input_text=None):
        return subprocess.run(
            [FISH, '--no-config', '-c', code], env=self.env,
            input=input_text, capture_output=True, text=True,
        )

    def launch(self, arguments=''):
        return self.run_fish(f"source '{LAUNCHER}'; claude {arguments}")

    def save_file(self, token=TOKEN):
        self.token_file.parent.mkdir(parents=True, exist_ok=True)
        self.token_file.write_text(token + '\n')
        self.token_file.chmod(0o600)

    def test_syntax(self):
        for source in [LAUNCHER, SAVER]:
            subprocess.run([FISH, '--no-config', '--no-execute', str(source)], check=True)
        subprocess.run(['/bin/sh', '-n', str(HELPER)], check=True)

    def test_helper_blocks_claude_services(self):
        for operation, expected in [('find-generic-password', 44), ('add-generic-password', 1), ('delete-generic-password', 44)]:
            for service in ['Claude Code', 'Claude Code-credentials', 'Claude Code-credentials-abcd1234']:
                with self.subTest(operation=operation, service=service):
                    result = subprocess.run([str(self.helper), operation, '-a', 'test-user', '-s', service], capture_output=True)
                    self.assertEqual(result.returncode, expected)
                    self.assertEqual(result.stdout, b'')

    def test_helper_blocks_interactive_security_writes(self):
        result = subprocess.run([str(self.helper), '-i'], input=b'add-generic-password -s "Claude Code-credentials"\n', capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b'')

    def test_helper_passes_through_help(self):
        expected = subprocess.run(['/usr/bin/security', 'help'], capture_output=True)
        actual = subprocess.run([str(self.helper), 'help'], capture_output=True)
        self.assertEqual((actual.returncode, actual.stdout, actual.stderr), (expected.returncode, expected.stdout, expected.stderr))

    def test_helper_passes_through_unrelated_service_help(self):
        arguments = ['find-generic-password', '-s', 'Unrelated App', '-h']
        expected = subprocess.run(['/usr/bin/security', *arguments], capture_output=True)
        actual = subprocess.run([str(self.helper), *arguments], capture_output=True)
        self.assertEqual((actual.returncode, actual.stdout, actual.stderr), (expected.returncode, expected.stdout, expected.stderr))

    def test_new_shells_load_saved_token_and_block_both_startup_reads(self):
        self.save_file()
        for _ in range(2):
            result = self.launch('--resume "session with spaces"')
            self.assertEqual(result.returncode, 0, result.stderr)
            output = json.loads(result.stdout)
            self.assertTrue(output['token_matches'])
            self.assertEqual(output['args'], ['--resume', 'session with spaces'])
            self.assertEqual(output['lookup_codes'], [44, 44])
            self.assertEqual(output['helper'], str(self.helper))
            self.assertNotIn(TOKEN, result.stdout + result.stderr)

    def test_missing_helper_fails_without_launching(self):
        self.save_file()
        self.helper.unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, '')
        self.assertIn('helper is missing', result.stderr)

    def test_launcher_preserves_exit_status(self):
        self.save_file()
        self.env['CLAUDE_TEST_EXIT'] = '17'
        self.assertEqual(self.launch().returncode, 17)

    def test_launcher_does_not_change_parent_path_or_export_token(self):
        self.save_file()
        result = self.run_fish(f"source '{LAUNCHER}'; set -l before_path (string join : -- $PATH); claude >/dev/null; test (string join : -- $PATH) = \"$before_path\"; and not set -q CLAUDE_CODE_OAUTH_TOKEN; and echo scope-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'scope-ok')

    def test_missing_or_empty_token_fails_without_launching(self):
        for save_empty in [False, True]:
            if save_empty:
                self.save_file('')
            result = self.launch()
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, '')
            self.assertIn('claude-token-save', result.stderr)

    def test_setup_token_runs_without_saved_token(self):
        result = self.launch('setup-token')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['lookup_codes'], [44, 44])

    def test_linux_passes_through_without_keychain_wrapper(self):
        self.env['HOST_OS'] = 'Linux'
        result = self.launch('--version')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotEqual(json.loads(result.stdout)['helper'], str(self.helper))

    def test_saver_creates_private_file_without_echoing_token(self):
        result = self.run_fish(f"source '{SAVER}'; claude-token-save", TOKEN + '\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.token_file.read_text(), TOKEN + '\n')
        self.assertEqual(stat.S_IMODE(self.token_file.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.token_file.parent.stat().st_mode), 0o700)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)

    def test_saver_reuses_current_exported_token(self):
        self.env['CLAUDE_CODE_OAUTH_TOKEN'] = TOKEN
        result = self.run_fish(f"source '{SAVER}'; claude-token-save")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.token_file.read_text(), TOKEN + '\n')

    def test_saver_rejects_whitespace_without_overwriting(self):
        self.save_file()
        result = self.run_fish(f"source '{SAVER}'; claude-token-save", 'invalid token\n')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.token_file.read_text(), TOKEN + '\n')


if __name__ == '__main__':
    unittest.main()
