"""Exercise actual publication refusals in disposable repository fixtures."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECKER = Path(__file__).with_name("check.py")
PUBLIC_NAME = "Slagathore"
PUBLIC_EMAIL = PUBLIC_NAME + "@users.noreply.github.com"


class PublicationControls(unittest.TestCase):
    def setUp(self):
        # Fixtures live under Git metadata, never in the evidence corpus.
        self.scratch = tempfile.TemporaryDirectory(dir=self.git_directory())
        self.root = Path(self.scratch.name)
        self.env = os.environ.copy()
        for name in ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"):
            self.env.pop(name, None)
        self.git("init", "-b", "main")
        for key, value in [("user.name", PUBLIC_NAME), ("user.email", PUBLIC_EMAIL),
                           ("core.autocrlf", "true"), ("core.hooksPath", ".githooks")]:
            self.git("config", key, value)
        self.write(".gitattributes", "* text=auto\n*.py text eol=lf\n")
        self.write("README.md", "A finite locomotion study.\n")
        self.git("add", ".")
        self.git("commit", "-m", "[publication/sdk1] Add fixture: finite source boundary")

    @staticmethod
    def git_directory():
        return subprocess.check_output(["git", "rev-parse", "--absolute-git-dir"], cwd=CHECKER.parents[2], text=True).strip()

    def tearDown(self):
        self.scratch.cleanup()

    def git(self, *words):
        return subprocess.check_output(["git", *words], cwd=self.root, env=self.env, stderr=subprocess.PIPE).decode().strip()

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(text.encode())
        return file

    def run_check(self, *words, data=None):
        return subprocess.run([sys.executable, str(CHECKER), *words], input=data,
                              cwd=self.root, env=self.env, text=True, capture_output=True)

    def blocked(self, mode, expected, *words, data=None):
        result = self.run_check(mode, *words, data=data)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(expected, result.stderr)

    def test_clean_staged_tree_message_and_range_pass(self):
        old = self.git("rev-parse", "HEAD")
        self.write("notes.md", "SDK and harness have separate entry points.\n")
        self.git("add", "notes.md")
        for mode in ("staged", "tree", "eol"):
            result = self.run_check(mode)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.git("commit", "-m", "[publication/sdk1] Add notes: explain both pillars")
        result = self.run_check("range", old, self.git("rev-parse", "HEAD"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_wrong_author_or_committer_is_refused(self):
        self.git("config", "user.name", "Other Author")
        self.blocked("staged", "Author and committer")
        self.git("commit", "--allow-empty", "-m", "Untrusted identity")
        self.blocked("range", "Commit author or committer", self.git("rev-parse", "HEAD^"), self.git("rev-parse", "HEAD"))

    def test_attribution_trailer_and_assistant_prose_are_refused(self):
        message = self.write("message.txt", "A change\n\nCo-" + "Authored-By: Another Person\n")
        self.blocked("message", "attribution", str(message))
        self.write("notes.md", "Made with " + "co" + "dex" + ".\n")
        self.git("add", "notes.md")
        self.blocked("staged", "Assistant name")

    def test_local_files_secret_files_and_game_assets_are_refused(self):
        for path in ("AGENTS.md", ".vscode/config.json", "docs/design_notes/notes.md", ".venv/tool.py",
                     "sdk/target/output.txt", ".github/instructions/notes.md", "local.key", "_spore_ref/model.rw4"):
            with self.subTest(path=path):
                self.write(path, "Local-only fixture.\n"); self.git("add", path)
                self.blocked("staged", "Forbidden publication path")
                self.git("reset", "HEAD", "--", path)

    def test_personal_email_and_home_path_are_refused(self):
        self.write("notes.md", "Contact: someone@" + "g" + "mail.com\n")
        self.git("add", "notes.md"); self.blocked("staged", "Personal mail provider")
        self.write("notes.md", "Working folder: " + "C:/Users/" + "operator/project\n")
        self.git("add", "notes.md"); self.blocked("staged", "Machine-local")

    def test_non_public_email_is_refused_but_examples_are_allowed(self):
        self.write("notes.md", "Contact: person@" + "private.example\n")
        self.git("add", "notes.md"); self.blocked("staged", "Non-public email")
        self.write("notes.md", "Contact: person@example.com and person@local.test\n")
        self.git("add", "notes.md")
        self.assertEqual(self.run_check("staged").returncode, 0)

    def test_credentials_and_private_key_headers_are_refused(self):
        values = ["gh" + "p_" + "x" * 36, "sk-" + "x" * 48, "AK" + "IA" + "A" * 16,
                  "xox" + "b-" + "x" * 32, "AI" + "za" + "x" * 35, "h" + "f_" + "x" * 30,
                  "-----BEGIN " + "PRIVATE KEY-----"]
        for value in values:
            with self.subTest(prefix=value[:4]):
                self.write("notes.md", value + "\n"); self.git("add", "notes.md")
                self.blocked("staged", "Possible credential")

    def test_large_blob_is_refused(self):
        with (self.root / "large.bin").open("wb") as handle:
            handle.truncate(96 * 1024 * 1024)
        self.git("add", "large.bin")
        self.blocked("staged", "exceeds 95 MiB")

    def test_unchanged_newline_drift_is_refused_and_safely_repaired(self):
        self.write("source.py", "x = 1\ny = 2\n"); self.git("add", "source.py")
        file = self.write("source.py", "x = 1\r\ny = 2\n")
        self.blocked("eol", "newline drift")
        self.blocked("staged", "newline drift")
        result = self.run_check("eol", "--fix", "source.py")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(file.read_bytes(), b"x = 1\ny = 2\n")

    def test_newline_repair_preserves_uncommitted_content(self):
        self.write("source.py", "x = 1\n"); self.git("add", "source.py")
        file = self.write("source.py", "x = 2\r\n")
        self.blocked("eol", "Refusing to overwrite", "--fix", "source.py")
        self.assertEqual(file.read_bytes(), b"x = 2\r\n")

    def test_configuration_and_stored_crlf_text_are_refused(self):
        self.git("config", "core.hooksPath", "other-hooks")
        self.blocked("staged", "Required checkout setting")
        self.git("config", "core.hooksPath", ".githooks")
        self.git("config", "core.autocrlf", "false")
        self.blocked("staged", "Required checkout setting")
        self.write("bad.py", "x = 1\r\n")
        oid = subprocess.check_output(["git", "hash-object", "-w", "--stdin"], input=b"x = 1\r\n", cwd=self.root).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", "100644," + oid + ",bad.py")
        self.blocked("tree", "Stored text is not LF")

    def test_push_checks_fast_forward_history_and_rejects_deletion(self):
        old = self.git("rev-parse", "HEAD")
        self.git("commit", "--allow-empty", "-m", "[publication/sdk1] Check fixture: forward history")
        new = self.git("rev-parse", "HEAD")
        good = f"refs/heads/main {new} refs/heads/main {old}\n"
        self.assertEqual(self.run_check("push", data=good).returncode, 0)
        self.blocked("push", "Non-fast-forward", data=f"refs/heads/main {old} refs/heads/main {new}\n")
        self.blocked("push", "Deleting published refs", data=f"(delete) {'0' * 40} refs/heads/main {new}\n")

    def test_bad_added_lines_in_an_earlier_commit_cannot_hide_at_tip(self):
        old = self.git("rev-parse", "HEAD")
        self.write("notes.md", "Co-" + "Authored-By: Another Person\n"); self.git("add", "notes.md")
        self.git("commit", "-m", "[publication/sdk1] Add fixture: intermediate content")
        self.git("rm", "notes.md"); self.git("commit", "-m", "[publication/sdk1] Remove fixture: tip content")
        self.blocked("range", "Attribution marker", old, self.git("rev-parse", "HEAD"))


if __name__ == "__main__":
    unittest.main()
