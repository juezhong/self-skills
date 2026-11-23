#!/usr/bin/env python3
"""链接检查命令：退出码 0 表示全部一致，1 表示至少一项不成立。

用法：
    python scripts/check-skill-links.py              # 检查 .gitignore 里所有子模块区块
    python scripts/check-skill-links.py --submodule x # 只检查某个子模块
    python scripts/check-skill-links.py --repo <dir>  # 指定仓库根（测试用）

检查项见 skill_links.SkillLinks.check()：悬空链接、越界链接、缺 SKILL.md、
已登记但磁盘无链接、有链接但未登记、Windows 上目标带正斜杠。
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import skill_links

if __name__ == "__main__":
    sys.exit(skill_links.main(["--check"] + sys.argv[1:]))
