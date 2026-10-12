import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "run_onchange_after_setup-pbpaste-server.sh.tmpl"
AGENTS = ["pbpaste-server", "pbcopy-server", "open-server"]


def render(platform):
    return subprocess.check_output(
        [shutil.which("chezmoi"), "--source", str(ROOT), "--override-data",
         json.dumps({"chezmoi": {"os": platform}}), "execute-template", "--file", str(TEMPLATE)],
        text=True,
    )


def main():
    script = render("darwin")
    assert not render("linux").strip()
    assert not render("windows").strip()
    subprocess.run(["/bin/bash", "-n"], input=script, text=True, check=True)
    with tempfile.TemporaryDirectory(prefix="clipboard-agents-") as directory:
        home = Path(directory)
        socat = home / "socat"
        socat.write_text("#!/bin/sh\nexit 0\n")
        socat.chmod(0o700)
        script = script.replace("/opt/homebrew/bin/socat", str(socat))
        launcher = home / "launchctl"
        launcher.write_text(
            '#!/bin/sh\n'
            'printf "%s\\n" "$*" >> "$CALL_LOG"\n'
            '[ "$1" != bootout ] || exit 3\n'
            'case "$3" in *"$FAIL_AGENT.plist") exit 5 ;; esac\n'
            'exit 0\n'
        )
        launcher.chmod(0o700)
        log = home / "calls"
        env = {**os.environ, "HOME": str(home), "PATH": f"{home}:{os.environ['PATH']}",
               "CALL_LOG": str(log), "FAIL_AGENT": "never"}
        result = subprocess.run(["/bin/bash"], input=script, env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        assert "tunnel launchd agents loaded" in result.stdout
        assert len(log.read_text().splitlines()) == 6
        for index, agent in enumerate(AGENTS):
            log.unlink()
            result = subprocess.run(["/bin/bash"], input=script,
                                    env={**env, "FAIL_AGENT": agent}, text=True, capture_output=True)
            assert result.returncode != 0, f"{agent}: failed bootstrap reported success"
            assert "tunnel launchd agents loaded" not in result.stdout
            assert len(log.read_text().splitlines()) == 2 * (index + 1)
        log.unlink()
        socat.unlink()
        result = subprocess.run(["/bin/bash"], input=script, env=env, text=True, capture_output=True)
        assert result.returncode != 0
        assert not log.exists()
    print("ok — platform gating, missing socat, absent agents, and bootstrap failures for all three agents")


if __name__ == "__main__":
    main()
