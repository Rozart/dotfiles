from pathlib import Path
import json
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "dot_config/rex/tab-number.lua"


class TabNumberTests(unittest.TestCase):
    def test_prompt_stays_local_for_remote_tab_contexts(self):
        lua = shutil.which("lua") or shutil.which("luajit")
        if not lua:
            self.skipTest("Lua interpreter is unavailable")
        result = subprocess.run(
            [lua, str(ROOT / ".tests/rex-tab-number.lua"), str(MODULE)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Client-local prompt, remote contexts, tab 12", result.stdout)

    def run_dialog_case(self, answers, expected, deadline=25):
        interpreter = shutil.which("osascript")
        if not interpreter:
            self.skipTest("AppleScript interpreter is unavailable")
        script = re.search(r"local dialog = \[\[\n(.*?)\n\]\]", MODULE.read_text(), re.S).group(1)
        script = re.sub(r"display dialog promptText[^\n]+", "testDialog(promptText, inputText, remaining)", script)
        script = script.replace("(current date) + 25", f"(current date) + {deadline}")
        values = ", ".join(json.dumps(answer, ensure_ascii=False) for answer in answers)
        harness = '''
property answers : {VALUES}
property callCount : 0
property initialRemaining : 0
on testDialog(promptText, inputText, remaining)
  set callCount to callCount + 1
  if remaining < 1 or remaining > 25 then error "Invalid deadline"
  if callCount > (count of answers) then error "Unexpected retry"
  set answer to item callCount of answers
  if initialRemaining > 0 and remaining ≥ initialRemaining then error "Deadline was reset"
  if answer is "__wait__" then
    set initialRemaining to remaining
    delay 1.1
    return {gave up:false, text returned:"0"}
  end if
  if answer is "__cancel__" then error number -128
  if answer is "__timeout__" then return {gave up:true, text returned:""}
  return {gave up:false, text returned:answer}
end testDialog
on runDialog()
BODY
end runDialog
set answer to runDialog()
return answer & "|" & callCount
'''.replace("VALUES", values).replace("BODY", script)
        result = subprocess.run(
            [interpreter, "-e", harness], capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), expected)

    def test_dialog_runtime_accepts_valid_numbers(self):
        for answer in ("12", "00012", "999999999"):
            with self.subTest(answer=answer):
                self.run_dialog_case([answer], answer + "|1")

    def test_dialog_runtime_retries_invalid_input(self):
        self.run_dialog_case(["0", "abc", "-1", "1.5", "", "1234567890", "１２", "1́", "😀", "12"], "12|10")

    def test_dialog_runtime_cancellation(self):
        self.run_dialog_case(["__cancel__"], "|1")
        self.run_dialog_case(["0", "__cancel__"], "|2")

    def test_dialog_runtime_timeout(self):
        self.run_dialog_case(["__timeout__"], "|1")

    def test_dialog_runtime_expired_deadline(self):
        self.run_dialog_case([], "|0", deadline=0)

    def test_dialog_runtime_retries_share_deadline(self):
        self.run_dialog_case(["__wait__", "12"], "12|2")

    def test_dialog_compiles_with_installed_applescript(self):
        compiler = shutil.which("osacompile")
        if not compiler:
            self.skipTest("AppleScript compiler is unavailable")
        script = re.search(r"local dialog = \[\[\n(.*?)\n\]\]", MODULE.read_text(), re.S).group(1)
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [compiler, "-o", str(Path(directory) / "dialog.scpt")],
                input=script, capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
