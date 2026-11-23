#!/usr/bin/env python3
"""技能链接器：把子模块里的技能目录链接到仓库根目录。

所有子模块共用这一份实现；入口脚本（如 link-mattpocock-skills.sh）只负责
挑选解释器并把子模块名与布局转进来，不再各自维护一份链接逻辑。

两条平台事实决定了下面的写法，改动前先读完：

1. Windows 的 NTFS 重解析点只接受反斜杠路径。用 POSIX 语义的解释器（MSYS、
   Cygwin）调用 os.symlink 时，目标会被写成 `submodules/...` 这样的正斜杠
   相对路径，链接看起来存在却解析不到——Explorer 里是空目录，扫描器读不到
   SKILL.md。因此建完链接必须验证能否解析，不能只看 os.symlink 是否抛异常。
2. junction 由 `cmd.exe /c mklink /J` 创建，参数必须是反斜杠路径，否则 cmd
   会把 `C:/Users` 里的 `/U` 当成开关，报 `Invalid switch - "Users"`。

junction 不需要管理员权限和开发者模式，所以链接创建失败时用它兜底；它在
Windows 上是目录重解析点，删除要用 rmdir 而不是 unlink。
"""

import argparse
import os
import subprocess
import sys

IGNORE_ENCODING = "utf-8"

OUTER_BEGIN = "# === 技能软链接 begin ==="
OUTER_END = "# === 技能软链接 end ==="

EXCLUDED_DIRECTORIES = frozenset(("deprecated", "in-progress", "misc", "node_modules"))

DEFAULT_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fail(message):
    print("error: {0}".format(message))
    return 1


def is_within(path, directory):
    """判断真实路径是否落在某个目录内，用于识别“本脚本创建的链接”。"""
    try:
        relative = os.path.relpath(path, directory)
    except ValueError:
        return False
    return relative == "." or not (
        relative == os.pardir or relative.startswith(os.pardir + os.sep))


def windows_path(path):
    """把 C:/x、/c/x、C:\\x 任意写法规范成 cmd.exe 接受的反斜杠路径。"""
    normalized = os.path.normpath(path)
    if os.sep == "/":
        parts = normalized.split("/")
        # MSYS 风格 /c/Users/... 还原成 C:/Users/...
        if len(parts) > 2 and len(parts[1]) == 1:
            normalized = parts[1] + ":/" + "/".join(parts[2:])
    return normalized.replace("/", "\\")


def link_is_live(destination):
    """链接必须真的解析到上游技能，否则扫描器看不到它。

    这是本脚本最重要的校验：os.symlink 成功不代表链接可用（见模块注释第 1 条）。
    """
    return os.path.isfile(os.path.join(destination, "SKILL.md"))


class SkillLinks(object):
    """一个子模块的链接集合：创建、删除、检查，以及 .gitignore 托管区块。"""

    def __init__(self, repo_root, submodule, categories=None):
        self.repo_root = os.path.abspath(repo_root)
        self.submodule = submodule
        self.categories = categories
        self.submodule_dir = os.path.join(self.repo_root, "submodules", submodule)
        self.source_dir = os.path.join(self.submodule_dir, "skills")
        self.gitignore_path = os.path.join(self.repo_root, ".gitignore")
        self.inner_begin = "# --- {0} begin ---".format(submodule)
        self.inner_end = "# --- {0} end ---".format(submodule)

    # ---- 链接所有权 ----

    def is_our_link(self, path):
        """只认最终落在本子模块里的符号链接或 junction，避免误删外来条目。

        junction 不是符号链接，`os.path.isjunction` 又要 Python 3.12，
        所以用「realpath 与自身路径不同」来识别重解析点，旧版本也能判断。
        """
        if not os.path.lexists(path):
            return False
        if os.path.islink(path):
            pass
        elif os.path.isdir(path) and os.path.realpath(path) != os.path.abspath(path):
            pass
        else:
            return False
        return is_within(os.path.realpath(path), os.path.realpath(self.submodule_dir))

    @staticmethod
    def remove_link(path):
        """删除符号链接或 junction；后者在 Windows 上需要用 rmdir。"""
        try:
            os.unlink(path)
        except OSError:
            os.rmdir(path)

    @staticmethod
    def exists_anyway(path):
        """junction 在某些 Python 版本上 lexists 返回 False，两条路都查一遍。"""
        return os.path.lexists(path) or os.path.exists(path)

    # ---- 链接创建 ----

    @staticmethod
    def create_junction(destination, target):
        """用 absolute target 建 junction；失败时把 cmd 的原始 stderr 抛出来。"""
        result = subprocess.run(
            ["cmd", "/c", "mklink", "/J",
             windows_path(destination), windows_path(target)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            detail = (result.stderr or result.stdout or b"").decode("mbcs", "replace")
            raise ValueError("mklink 失败（{0}）：{1}".format(
                result.returncode, detail.strip() or "无输出"))

    def create_link(self, destination, relative_target):
        """先试相对符号链接，建不了或解析不了就退回 junction。"""
        absolute_target = os.path.abspath(
            os.path.join(self.repo_root, relative_target))

        # MSYS/Cygwin 的 Python 写出的链接目标是 POSIX 路径，Windows 不解析，
        # 所以在这里直接走 junction，不浪费一次注定失败的创建。
        if os.sep == "/" and sys.platform in ("msys", "cygwin"):
            print("note: MSYS interpreter cannot write Windows link targets; "
                  "using junction")
            self.create_junction(destination, absolute_target)
            return
        # 真正的 Unix（Linux/macOS）没有 junction，普通相对软链接即可。
        if os.sep == "/":
            os.symlink(relative_target, destination)
            return

        try:
            os.symlink(relative_target, destination)
        except OSError as exception:
            print("note: symlink unavailable ({0}); using junction".format(
                getattr(exception, "winerror", exception)))
        else:
            if link_is_live(destination):
                return
            # 链接建成了却读不到目标：多半是重解析点里的路径未被解析。
            print("note: symlink target does not resolve; using junction")
            self.remove_link(destination)
        self.create_junction(destination, absolute_target)

    # ---- 上游技能枚举 ----

    def promoted_skills(self):
        """列出子模块里可直接链接的技能：目录中含 SKILL.md，排除工具目录。"""
        roots = [os.path.join(self.source_dir, category)
                 for category in self.categories] if self.categories else [self.source_dir]
        skills = {}
        for root_dir in roots:
            if not os.path.isdir(root_dir):
                continue
            for root, directories, filenames in os.walk(root_dir):
                directories[:] = sorted(
                    directory for directory in directories
                    if directory not in EXCLUDED_DIRECTORIES)
                if "SKILL.md" not in filenames:
                    continue
                name = os.path.basename(root)
                if name in skills:
                    raise ValueError("duplicate promoted skill '{0}'".format(name))
                skills[name] = os.path.relpath(root, self.repo_root)
        return skills

    # ---- .gitignore 托管区块 ----

    def read_ignore(self):
        try:
            with open(self.gitignore_path, "r", encoding=IGNORE_ENCODING,
                      errors="surrogateescape") as ignore_file:
                return [line.rstrip("\n") for line in ignore_file]
        except OSError:
            return []

    def _block_bounds(self):
        lines = self.read_ignore()
        starts = [index for index, line in enumerate(lines) if line == self.inner_begin]
        ends = [index for index, line in enumerate(lines) if line == self.inner_end]
        return lines, starts, ends

    def write_block(self, skill_names):
        """只重写本子模块的区块，区块外内容逐行保留。"""
        lines, starts, ends = self._block_bounds()
        if starts or ends:
            if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
                raise ValueError("incomplete {0} block in .gitignore".format(self.submodule))
            del lines[starts[0]:ends[0] + 1]

        outer_starts = [index for index, line in enumerate(lines) if line == OUTER_BEGIN]
        outer_ends = [index for index, line in enumerate(lines) if line == OUTER_END]
        if not outer_starts and not outer_ends:
            if lines and lines[-1] != "":
                lines.append("")
            lines.extend((OUTER_BEGIN, OUTER_END))
            insert_at = len(lines) - 1
        elif len(outer_starts) == 1 and len(outer_ends) == 1 and outer_starts[0] < outer_ends[0]:
            insert_at = outer_ends[0]
        else:
            raise ValueError("incomplete skill-links block in .gitignore")

        lines[insert_at:insert_at] = (
            [self.inner_begin] + sorted(skill_names) + [self.inner_end])

        temporary_path = self.gitignore_path + ".tmp"
        with open(temporary_path, "w", encoding=IGNORE_ENCODING,
                  errors="surrogateescape", newline="\n") as ignore_file:
            ignore_file.write("\n".join(lines) + "\n")
        os.replace(temporary_path, self.gitignore_path)

    def managed_names(self):
        """读取 .gitignore 中登记的本子模块技能名，供检查命令做漂移比对。"""
        lines, starts, ends = self._block_bounds()
        if len(starts) != 1 or len(ends) != 1:
            return None
        return [line for line in lines[starts[0] + 1:ends[0]]
                if line.strip() and not line.startswith("#")]

    # ---- 操作 ----

    def install(self, skills, replace_block=True):
        # 冲突预检：同名路径只有归本脚本所有时才允许覆盖，其余先整体报错，
        # 避免建到一半才发现冲突、留下半成品状态。
        conflicts = [name for name in skills
                     if self.exists_anyway(os.path.join(self.repo_root, name))
                     and not self.is_our_link(os.path.join(self.repo_root, name))]
        if conflicts:
            raise ValueError(
                "目标已存在且不是本脚本的链接，请先手动处理：{0}".format(
                    ", ".join(sorted(conflicts))))

        for name in sorted(skills):
            destination = os.path.join(self.repo_root, name)
            if self.exists_anyway(destination):
                self.remove_link(destination)
            self.create_link(destination, skills[name])
            if not link_is_live(destination):
                raise ValueError("链接创建后无法解析到 SKILL.md：{0}".format(destination))
            print("linked {0} -> {1} ({2})".format(name, skills[name], self.repo_root))

        # 只处理部分技能时，托管区块要并上原有登记，否则其余的链接会变成
        # “存在但未登记”，--check 立刻报错。
        if replace_block:
            registered = sorted(skills)
        else:
            registered = sorted(set(self.managed_names() or []) | set(skills))
        self.write_block(registered)
        print("wrote {0} {1} skill names to .gitignore".format(
            len(registered), self.submodule))

    def uninstall(self):
        """删除本子模块的链接；按约定不修改 .gitignore。"""
        removed = 0
        for name in sorted(os.listdir(self.repo_root)):
            destination = os.path.join(self.repo_root, name)
            if not self.is_our_link(destination):
                continue
            self.remove_link(destination)
            print("unlinked {0}".format(name))
            removed += 1
        print("removed {0} {1} skill links; .gitignore was not changed".format(
            removed, self.submodule))

    def check(self):
        """返回问题列表；空列表表示链接与 .gitignore 完全一致。"""
        problems = []
        managed = self.managed_names()
        if managed is None:
            problems.append(".gitignore 中缺少或损坏 {0} 区块".format(self.submodule))
            managed = []

        for name in managed:
            destination = os.path.join(self.repo_root, name)
            if not self.exists_anyway(destination):
                problems.append("{0}: 已登记但磁盘上没有链接".format(name))
                continue
            if not self.is_our_link(destination):
                problems.append("{0}: 存在但不是指向 {1} 的链接".format(name, self.submodule))
                continue
            if not link_is_live(destination):
                problems.append("{0}: 链接无法解析到 SKILL.md".format(name))
                continue
            if sys.platform in ("win32", "msys", "cygwin") and os.path.islink(destination):
                # Windows 不解析重解析点里的正斜杠：这类目标就是本次事故的形态。
                target = os.readlink(destination)
                if "/" in target:
                    problems.append("{0}: 链接目标使用正斜杠，Windows 无法解析".format(name))

        for name in sorted(os.listdir(self.repo_root)):
            destination = os.path.join(self.repo_root, name)
            if self.is_our_link(destination) and name not in managed:
                problems.append("{0}: 链接存在但未登记到 .gitignore".format(name))
        return problems


def resolve_layout(arguments):
    if arguments.categories is not None:
        categories = [item for item in arguments.categories.split(",") if item]
        return categories or None
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="skill_links.py",
        description="为技能子模块建立/删除/检查根目录链接，并维护 .gitignore 托管区块。",
        epilog=(
            "平台说明:\n"
            "  Windows 上相对符号链接可能建不了（需要开发者模式或管理员权限），\n"
            "  此时改用 junction；junction 的目标必须是绝对反斜杠路径。\n"
            "  MSYS/Cygwin 的 Python 会把目标写成 POSIX 路径，Windows 不解析，\n"
            "  所以这类解释器直接走 junction。\n"
            "  Windows 上请用原生 Windows 版 Python（os.sep 为反斜杠）；\n"
            "  入口脚本负责挑解释器，缺省顺序是 .venv → python3 → python → py -3。\n"
            "  真 Unix（Linux/macOS）使用普通的相对符号链接。"),
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=DEFAULT_REPO,
                        help="仓库根目录（默认取本文件所在目录的上一级）")
    parser.add_argument("--submodule", help="子模块目录名，例如 mattpocock-skills")
    parser.add_argument("--categories", default=None,
                        help="分类子目录，逗号分隔，例如 engineering,productivity；"
                             "缺省表示 skills/ 下直接放技能（扁平布局）")
    parser.add_argument("--unlink", action="store_true", help="删除本子模块的链接，不改 .gitignore")
    parser.add_argument("--check", action="store_true",
                        help="检查链接与 .gitignore 是否一致；不传 --submodule 时检查全部区块")
    parser.add_argument("names", nargs="*", help="只处理指定技能名（缺省为全部）")
    arguments = parser.parse_args(argv)

    if arguments.check:
        problems = []
        if arguments.submodule:
            links = SkillLinks(arguments.repo, arguments.submodule,
                               resolve_layout(arguments))
            problems = links.check()
        else:
            for submodule in discover_submodules(arguments.repo):
                problems.extend(SkillLinks(arguments.repo, submodule).check())
        for problem in problems:
            print(problem)
        if problems:
            print("{0} problem(s) found".format(len(problems)))
            return 1
        return 0

    if not arguments.submodule:
        return fail("--submodule is required (or use --check to check all blocks)")
    links = SkillLinks(arguments.repo, arguments.submodule, resolve_layout(arguments))

    if arguments.unlink:
        # 反向操作不依赖子模块是否仍已初始化。
        links.uninstall()
        return 0

    if not os.path.isdir(links.source_dir):
        return fail("submodule is not initialized; run: git submodule update --init {0}".format(
            os.path.join("submodules", arguments.submodule)))

    try:
        skills = links.promoted_skills()
        if arguments.names:
            missing = [name for name in arguments.names if name not in skills]
            if missing:
                return fail("unknown skill(s): {0}".format(", ".join(missing)))
            skills = {name: skills[name] for name in arguments.names}
        links.install(skills, replace_block=not arguments.names)
    except (ValueError, OSError) as exception:
        return fail(str(exception))
    return 0


def discover_submodules(repo_root):
    """从 .gitignore 的外层托管区块推导所有子模块名。"""
    ignored = SkillLinks(repo_root, "_probe_").read_ignore()
    names = []
    for line in ignored:
        if line.startswith("# --- ") and line.endswith(" begin ---"):
            names.append(line[len("# --- "):-len(" begin ---")])
    return names


if __name__ == "__main__":
    sys.exit(main())
