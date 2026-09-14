#!/usr/bin/env python3
"""将 mattpocock-skills 链接到当前仓库的 skills 根目录。

本脚本参考子模块的 scripts/link-skills.sh：递归查找并链接已推广技能。
上游同时管理 ~/.agents/skills 与 ~/.claude/skills；当前仓库本身就是
~/.agents/skills，且 ~/.claude/skills 可以指向它，因此这里只管理当前仓库。
"""

from __future__ import print_function

import os
import sys


# 所有路径都由本文件的位置计算，因而可从任意工作目录调用。
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILLS_DIR = os.path.dirname(SCRIPT_DIR)
SUBMODULE_RELATIVE = os.path.join("submodules", "mattpocock-skills")
SUBMODULE_DIR = os.path.join(SKILLS_DIR, SUBMODULE_RELATIVE)
SOURCE_DIR = os.path.join(SUBMODULE_DIR, "skills")
GITIGNORE_PATH = os.path.join(SKILLS_DIR, ".gitignore")

# .gitignore 中由本脚本单独维护的区块边界。
OUTER_BEGIN = "# === 技能软链接 begin ==="
OUTER_END = "# === 技能软链接 end ==="
INNER_BEGIN = "# --- mattpocock-skills begin ---"
INNER_END = "# --- mattpocock-skills end ---"
EXCLUDED_DIRECTORIES = frozenset((
    "deprecated", "in-progress", "misc", "node_modules",
))


def fail(message):
    print("error: {0}".format(message), file=sys.stderr)
    return 1


def is_within(path, directory):
    """判断 path 是否位于 directory 内；兼容 Python 3.3 及以上版本。"""
    try:
        relative = os.path.relpath(path, directory)
    except ValueError:
        return False
    return relative == "." or not (
        relative == os.pardir or relative.startswith(os.pardir + os.sep))


def is_our_link(path):
    """只识别最终指向 mattpocock 子模块的软链接，供 --unlink 安全删除。"""
    return os.path.islink(path) and is_within(
        os.path.realpath(path), os.path.realpath(SUBMODULE_DIR))


def upstream_promoted_skills():
    """用标准库复现上游的 find 规则，并额外排除 in-progress。

    Equivalent to:
      find "$REPO/skills" -name SKILL.md \
        -not -path '*/node_modules/*' \
        -not -path '*/deprecated/*' \
        -not -path '*/misc/*'
    """
    skills = {}
    for root, directories, filenames in os.walk(SOURCE_DIR):
        directories[:] = sorted(
            directory for directory in directories
            if directory not in EXCLUDED_DIRECTORIES)
        if "SKILL.md" not in filenames:
            continue
        name = os.path.basename(root)
        source = os.path.relpath(root, SKILLS_DIR)
        if name in skills:
            raise ValueError("duplicate promoted skill '{0}'".format(name))
        skills[name] = source
    return skills


def read_ignore():
    """读取现有 .gitignore；文件不存在时从空内容开始。"""
    try:
        with open(GITIGNORE_PATH, "r") as ignore_file:
            return [line.rstrip("\n") for line in ignore_file]
    except IOError:
        return []


def remove_inner_block(lines):
    """仅移除 mattpocock 的托管区块，保留其他子模块的区块。"""
    starts = [index for index, line in enumerate(lines) if line == INNER_BEGIN]
    ends = [index for index, line in enumerate(lines) if line == INNER_END]
    if not starts and not ends:
        return lines
    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        raise ValueError("incomplete mattpocock-skills block in .gitignore")
    return lines[:starts[0]] + lines[ends[0] + 1:]


def write_ignore(skill_names):
    """全量链接成功后，按当前技能集合重建本脚本的 ignore 区块。"""
    lines = remove_inner_block(read_ignore())
    starts = [index for index, line in enumerate(lines) if line == OUTER_BEGIN]
    ends = [index for index, line in enumerate(lines) if line == OUTER_END]
    if not starts and not ends:
        if lines and lines[-1] != "":
            lines.append("")
        lines.extend((OUTER_BEGIN, OUTER_END))
        end = len(lines) - 1
    elif len(starts) == 1 and len(ends) == 1 and starts[0] < ends[0]:
        end = ends[0]
    else:
        raise ValueError("incomplete skill-links block in .gitignore")

    lines[end:end] = [INNER_BEGIN] + sorted(skill_names) + [INNER_END]
    temporary_path = GITIGNORE_PATH + ".tmp"
    with open(temporary_path, "w") as ignore_file:
        ignore_file.write("\n".join(lines) + "\n")
    os.replace(temporary_path, GITIGNORE_PATH)


def uninstall():
    """反向删除本子模块的链接；按约定绝不修改 .gitignore。"""
    removed = 0
    for name in sorted(os.listdir(SKILLS_DIR)):
        destination = os.path.join(SKILLS_DIR, name)
        if not is_our_link(destination):
            continue
        os.unlink(destination)
        print("unlinked {0}".format(name))
        removed += 1
    print("removed {0} mattpocock skill links; .gitignore was not changed".format(
        removed))


def install(skills):
    # 先预检所有目标，确保发生冲突时不会只创建一半链接。
    existing = [name for name in skills
                if os.path.lexists(os.path.join(SKILLS_DIR, name))]
    if existing:
        raise ValueError(
            "目标已存在，请先执行 --unlink 后再重建：{0}".format(
                ", ".join(sorted(existing))))

    # 所有目标均不存在时，才开始创建相对软链接，便于整个仓库移动或克隆。
    for name in sorted(skills):
        destination = os.path.join(SKILLS_DIR, name)
        os.symlink(skills[name], destination)
        print("linked {0} -> {1} ({2})".format(name, skills[name], SKILLS_DIR))

    write_ignore(skills)
    print("wrote {0} mattpocock skill names to .gitignore".format(len(skills)))


def main(arguments):
    if arguments == ["-h"] or arguments == ["--help"]:
        print("usage: scripts/link-mattpocock-skills.sh [--unlink]")
        return 0
    if arguments == ["--unlink"]:
        # 反向操作不依赖子模块是否仍已初始化。
        uninstall()
        return 0
    if arguments:
        return fail("this upstream-compatible installer accepts only --unlink")
    if not os.path.isdir(SOURCE_DIR):
        return fail("submodule is not initialized; run: git submodule update --init {0}".format(
            SUBMODULE_RELATIVE))
    try:
        install(upstream_promoted_skills())
    except ValueError as exception:
        return fail(str(exception))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
