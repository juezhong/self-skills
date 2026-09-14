#!/usr/bin/env python3
"""将 agent-toolkit 子模块的技能链接到当前仓库根目录。"""

from __future__ import print_function

import os
import sys


# 所有路径都由本文件的位置计算，因而可从任意工作目录调用。
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILLS_DIR = os.path.dirname(SCRIPT_DIR)
SUBMODULE_RELATIVE = os.path.join("submodules", "agent-toolkit")
SUBMODULE_DIR = os.path.join(SKILLS_DIR, SUBMODULE_RELATIVE)
SOURCE_DIR = os.path.join(SUBMODULE_DIR, "skills")
GITIGNORE_PATH = os.path.join(SKILLS_DIR, ".gitignore")

# .gitignore 中由本脚本单独维护的区块边界。
OUTER_BEGIN = "# === 技能软链接 begin ==="
OUTER_END = "# === 技能软链接 end ==="
INNER_BEGIN = "# --- agent-toolkit begin ---"
INNER_END = "# --- agent-toolkit end ---"


def fail(message):
    """统一将可预期错误输出到标准错误流。"""
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
    """只识别最终指向 agent-toolkit 子模块的软链接，供 --unlink 安全删除。"""
    return os.path.islink(path) and is_within(
        os.path.realpath(path), os.path.realpath(SUBMODULE_DIR))


def discover_skills():
    """递归收集每个包含 SKILL.md 的目录，兼容未来新增分类目录。"""
    skills = {}
    for root, directories, filenames in os.walk(SOURCE_DIR):
        directories.sort()
        if "SKILL.md" not in filenames:
            continue
        name = os.path.basename(root)
        source = os.path.relpath(root, SKILLS_DIR)
        if name in skills:
            raise ValueError("发现重名技能：{0}".format(name))
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
    """仅移除 agent-toolkit 的托管区块，保留其他子模块的区块。"""
    starts = [index for index, line in enumerate(lines) if line == INNER_BEGIN]
    ends = [index for index, line in enumerate(lines) if line == INNER_END]
    if not starts and not ends:
        return lines
    if len(starts) != 1 or len(ends) != 1 or starts[0] >= ends[0]:
        raise ValueError(".gitignore 中的 agent-toolkit 托管区块不完整")
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
        raise ValueError(".gitignore 中的技能软链接托管区块不完整")

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
    print("removed {0} agent-toolkit skill links; .gitignore was not changed".format(
        removed))


def install(skills):
    """预检后创建全部链接；不覆盖任何已有文件、目录或软链接。"""
    existing = [name for name in skills
                if os.path.lexists(os.path.join(SKILLS_DIR, name))]
    if existing:
        raise ValueError(
            "目标已存在，请先执行 --unlink 后再重建：{0}".format(
                ", ".join(sorted(existing))))

    # 所有目标均不存在时，才开始创建相对软链接，便于整个仓库移动或克隆。
    for name in sorted(skills):
        os.symlink(skills[name], os.path.join(SKILLS_DIR, name))
        print("linked {0} -> {1} ({2})".format(name, skills[name], SKILLS_DIR))
    write_ignore(skills)
    print("wrote {0} agent-toolkit skill names to .gitignore".format(len(skills)))


def main(arguments):
    if arguments == ["--unlink"]:
        # 反向操作不依赖子模块是否仍已初始化。
        uninstall()
        return 0
    if arguments:
        return fail("本脚本只接受 --unlink 参数")
    if not os.path.isdir(SOURCE_DIR):
        return fail("子模块未初始化，请先执行: git submodule update --init {0}".format(
            SUBMODULE_RELATIVE))
    try:
        install(discover_skills())
    except ValueError as exception:
        return fail(str(exception))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
