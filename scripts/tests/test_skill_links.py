"""CLI 层测试：把入口脚本当黑盒进程跑，断言退出码、输出和文件系统。

所有用例都在临时目录里造一个迷你仓库，不碰真实仓库的链接。
运行：python -m unittest discover -s scripts/tests
"""

import contextlib
import os
import shutil
import subprocess
import sys
import unittest
import uuid

CORE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skill_links.py"
)
IS_WINDOWS = os.name == "nt"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _writable(path):
    """目录能建、能删才用它做临时根。"""
    try:
        os.makedirs(path, exist_ok=True)
        probe = os.path.join(path, "probe-%s" % uuid.uuid4().hex[:8])
        with open(probe, "w", encoding="utf-8") as handle:
            handle.write("x")
        os.remove(probe)
        return True
    except OSError:
        return False


def _pick_tmp_root():
    # 先按 AGENTS.md 用系统临时目录；沙箱里它可能禁止建子目录，再退回仓库内。
    for candidate in (os.environ.get("TMPDIR"), os.environ.get("TEMP"), os.environ.get("TMP")):
        if candidate and _writable(candidate):
            return candidate
    fallback = os.path.join(REPO_ROOT, ".test-tmp")
    os.makedirs(fallback, exist_ok=True)
    return fallback


BASE_TMP = _pick_tmp_root()


@contextlib.contextmanager
def temp_dir():
    """建一个可写目录。

    不用 tempfile.mkdtemp：它以 0o700 建目录，在 Windows 上这批目录
    里再建子目录会被拒绝访问（本次踩到），普通 makedirs 反而正常。
    """
    path = os.path.join(BASE_TMP, "case-%s" % uuid.uuid4().hex[:12])
    os.makedirs(path)
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)

GITIGNORE_HEADER = "# 注释：技能链接\nnode_modules/\n"


def make_repo(root, names, submodule="demo-skills", layout="categorized"):
    """造一个带子模块、.gitignore 和若干 SKILL.md 的临时仓库。"""
    skills_root = os.path.join(root, "submodules", submodule, "skills")
    for name in names:
        directory = (
            os.path.join(skills_root, "engineering", name)
            if layout == "categorized"
            else os.path.join(skills_root, name)
        )
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "SKILL.md"), "w", encoding="utf-8") as handle:
            handle.write("# %s\n" % name)
    with open(os.path.join(root, ".gitignore"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(GITIGNORE_HEADER)
    return skills_root


def run_cli(root, submodule="demo-skills", categories="engineering", *extra):
    argv = [sys.executable, CORE, "--repo", root, "--submodule", submodule]
    if categories:
        argv += ["--categories", categories]
    argv += list(extra)
    return subprocess.run(argv, capture_output=True, text=True, encoding="utf-8", errors="replace")


def read_gitignore(root):
    with open(os.path.join(root, ".gitignore"), "r", encoding="utf-8") as handle:
        return handle.read()


def make_foreign_link(root):
    """造一个不属于本子模块的链接，模拟 ego-browser 那种既有 junction。"""
    target = os.path.join(root, "elsewhere", "ego-skills")
    os.makedirs(target, exist_ok=True)
    destination = os.path.join(root, "ego-browser")
    if IS_WINDOWS:
        result = subprocess.run(
            ["cmd", "/c", "mklink", "/J", destination, target],
            capture_output=True, text=True, encoding="mbcs", errors="replace",
        )
        if result.returncode != 0:
            raise unittest.SkipTest("无法创建 junction：%s" % result.stderr.strip())
    else:
        os.symlink(target, destination)
    return destination


class SkillLinksTest(unittest.TestCase):
    def setUp(self):
        self._stack = contextlib.ExitStack()
        self.root = self._stack.enter_context(temp_dir())
        self.names = ["alpha", "beta"]
        make_repo(self.root, self.names)

    def tearDown(self):
        self._stack.close()

    def test_install_creates_resolvable_links(self):
        result = run_cli(self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in self.names:
            self.assertTrue(
                os.path.isfile(os.path.join(self.root, name, "SKILL.md")), name
            )
        ignore = read_gitignore(self.root)
        for name in self.names:
            self.assertIn(name, ignore)
        self.assertIn("注释：技能链接", ignore)
        self.assertEqual(run_cli(self.root, "demo-skills", "engineering", "--check").returncode, 0)

    def test_install_is_idempotent(self):
        self.assertEqual(run_cli(self.root).returncode, 0)
        first = read_gitignore(self.root)
        result = run_cli(self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(first, read_gitignore(self.root))
        self.assertEqual(sorted(os.listdir(self.root)).count("alpha"), 1)

    def test_unlink_only_removes_own_links(self):
        foreign = make_foreign_link(self.root)
        self.assertEqual(run_cli(self.root).returncode, 0)
        ignore_before = read_gitignore(self.root)
        result = run_cli(self.root, "demo-skills", "engineering", "--unlink")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(os.path.isdir(foreign))
        for name in self.names:
            self.assertFalse(os.path.lexists(os.path.join(self.root, name)), name)
        self.assertEqual(ignore_before, read_gitignore(self.root))

    def test_install_refuses_to_overwrite_plain_file(self):
        occupied = os.path.join(self.root, "alpha")
        with open(occupied, "w", encoding="utf-8") as handle:
            handle.write("keep me")
        result = run_cli(self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("alpha", result.stderr + result.stdout)
        with open(occupied, "r", encoding="utf-8") as handle:
            self.assertEqual(handle.read(), "keep me")

    def test_check_flags_drift_and_dangling(self):
        self.assertEqual(run_cli(self.root).returncode, 0)
        path = os.path.join(self.root, ".gitignore")
        lines = [line for line in read_gitignore(self.root).splitlines() if line.strip() != "beta"]
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(lines) + "\n")
        result = run_cli(self.root, "demo-skills", "engineering", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("beta", result.stdout + result.stderr)

    def test_check_flags_missing_link(self):
        self.assertEqual(run_cli(self.root).returncode, 0)
        os.rename(os.path.join(self.root, "alpha"), os.path.join(self.root, "moved-away"))
        result = run_cli(self.root, "demo-skills", "engineering", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("alpha", result.stdout + result.stderr)

    @unittest.skipUnless(IS_WINDOWS, "只检查 Windows 上写坏路径的链接")
    def test_check_flags_forward_slash_target(self):
        self.assertEqual(run_cli(self.root).returncode, 0)
        destination = os.path.join(self.root, "alpha")
        os.rename(destination, destination + "-old")
        try:
            os.symlink("submodules/demo-skills/skills/engineering/alpha", destination)
        except OSError as error:
            self.skipTest("无法创建符号链接：%s" % error)
        self.assertIn("/", os.readlink(destination))
        result = run_cli(self.root, "demo-skills", "engineering", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("alpha", result.stdout + result.stderr)

    @unittest.skipIf(IS_WINDOWS, "扁平布局在 Windows 上行为相同，这里只覆盖 Unix 分支")
    def test_flat_layout(self):
        with temp_dir() as root:
            make_repo(root, ["alpha"], layout="flat")
            result = run_cli(root, "demo-skills", "")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(os.path.isfile(os.path.join(root, "alpha", "SKILL.md")))


class SelectiveInstallTest(unittest.TestCase):
    def test_selective_install_keeps_registered_entries(self):
        """只装一个技能后，其余已登记的链接不能被写成“未登记”。"""
        with temp_dir() as root:
            make_repo(root, ["alpha", "beta", "gamma"])
            self.assertEqual(run_cli(root).returncode, 0)
            result = run_cli(root, "demo-skills", "engineering", "alpha")
            self.assertEqual(result.returncode, 0, result.stderr)
            ignore = read_gitignore(root)
            for name in ("alpha", "beta", "gamma"):
                self.assertIn(name, ignore)
            self.assertEqual(
                run_cli(root, "demo-skills", "engineering", "--check").returncode, 0)


class EntryScriptTest(unittest.TestCase):
    """入口脚本是黑盒：只断言退出码、输出和它建出来的链接。"""

    def _make_repo(self, root):
        make_repo(root, ["alpha"], submodule="mattpocock-skills")
        scripts_dir = os.path.join(root, "scripts")
        os.makedirs(scripts_dir, exist_ok=True)
        source_dir = os.path.dirname(CORE)
        for name in ("link-mattpocock-skills.py", "skill_links.py"):
            shutil.copy2(os.path.join(source_dir, name), os.path.join(scripts_dir, name))
        return scripts_dir

    def test_python_entry_installs_and_checks(self):
        with temp_dir() as root:
            scripts_dir = self._make_repo(root)
            entry = os.path.join(scripts_dir, "link-mattpocock-skills.py")
            result = subprocess.run(
                [sys.executable, entry], capture_output=True, text=True,
                encoding="utf-8", errors="replace")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(os.path.isfile(
                os.path.join(root, "alpha", "SKILL.md")))
            check = subprocess.run(
                [sys.executable, entry, "--check"], capture_output=True, text=True,
                encoding="utf-8", errors="replace")
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)

    @unittest.skipUnless(shutil.which("bash") and shutil.which("uname"),
                         "没有 bash/uname，跳过 shell 入口")
    def test_shell_entry_installs_and_checks(self):
        with temp_dir() as root:
            scripts_dir = self._make_repo(root)
            copy2 = shutil.copy2
            copy2(
                os.path.join(os.path.dirname(CORE), "link-mattpocock-skills.sh"),
                os.path.join(scripts_dir, "link-mattpocock-skills.sh"))
            entry = os.path.join(scripts_dir, "link-mattpocock-skills.sh")
            result = subprocess.run(
                ["bash", entry], capture_output=True, text=True,
                encoding="utf-8", errors="replace")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(os.path.isfile(
                os.path.join(root, "alpha", "SKILL.md")))
            check = subprocess.run(
                ["bash", entry, "--check"], capture_output=True, text=True,
                encoding="utf-8", errors="replace")
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)


class VendoredCopyTest(unittest.TestCase):
    def test_skill_template_copy_matches_core(self):
        """add-skills-submodule 里的副本必须和 scripts/skill_links.py 一致。"""
        repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        vendored = os.path.join(repo, "add-skills-submodule", "scripts", "skill_links.py")
        if not os.path.isfile(vendored):
            self.skipTest("没有 vendored 副本")
        with open(CORE, "rb") as handle:
            core_bytes = handle.read()
        with open(vendored, "rb") as handle:
            vendored_bytes = handle.read()
        self.assertEqual(len(core_bytes), len(vendored_bytes))
        self.assertTrue(core_bytes == vendored_bytes, "副本已过期，重新复制 scripts/skill_links.py")


if __name__ == "__main__":
    unittest.main()
