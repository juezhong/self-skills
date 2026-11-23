#!/usr/bin/env python3
"""兼容入口：mattpocock-skills 的链接安装。

链接逻辑在 scripts/skill_links.py，这里只绑定子模块名与布局，便于
`python scripts/link-mattpocock-skills.py` 直接运行。
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import skill_links

if __name__ == "__main__":
    sys.exit(skill_links.main([
        "--repo", os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "--submodule", "mattpocock-skills",
        "--categories", "engineering,productivity",
    ] + sys.argv[1:]))
