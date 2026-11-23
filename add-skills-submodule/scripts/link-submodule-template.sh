#!/usr/bin/env bash
# 模板：为子模块 __SUBMODULE_NAME__ 建立技能链接。
#
# 链接逻辑在仓库根的 scripts/skill_links.py：它处理 Windows junction 兜底、
# 路径规范化、幂等安装和 .gitignore 托管区块。本脚本只挑解释器并转交。
#
# Windows（MSYS/Cygwin/bash）只接受原生 Windows 解释器（os.sep 是反斜杠）：
# POSIX 版 Python 写出的正斜杠目标，Windows 不解析。没有可用解释器时先建
# .venv，优先用 uv。
#
# 用法:
#   bash scripts/link-__SUBMODULE_NAME__.sh              # 全量安装
#   bash scripts/link-__SUBMODULE_NAME__.sh skill-a      # 只处理指定技能
#   bash scripts/link-__SUBMODULE_NAME__.sh --unlink     # 删除本子模块的链接
#   bash scripts/link-__SUBMODULE_NAME__.sh --check      # 检查链接与 .gitignore 是否一致
#
# 布局：分类结构（skills/engineering/...）设 CATEGORIES；扁平结构设为空字符串。
set -euo pipefail

case "$0" in
    */*) SCRIPT_DIR="${0%/*}" ;;
    *) SCRIPT_DIR="." ;;
esac
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
SKILLS_DIR="${SCRIPT_DIR%/*}"
SUBMODULE="__SUBMODULE_NAME__"
CATEGORIES="engineering,productivity"
CORE="$SCRIPT_DIR/skill_links.py"
VENV_DIR="$SKILLS_DIR/.venv"

if [ ! -f "$CORE" ]; then
    echo "error: 缺少 $CORE" >&2
    echo "       从 add-skills-submodule 技能目录复制一份到仓库 scripts/ 下再运行。" >&2
    exit 1
fi

is_native_python() {
    "$1" -c 'import os,sys; sys.exit(0 if os.sep == chr(92) else 1)' >/dev/null 2>&1
}

needs_native_python() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
    esac
    return 1
}

usable_python() {
    [ -n "${1:-}" ] || return 1
    if [ -x "$1" ]; then
        :
    elif ! command -v "$1" >/dev/null 2>&1; then
        return 1
    fi
    if needs_native_python; then
        is_native_python "$1"
    else
        "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1
    fi
}

venv_python() {
    for candidate in "$VENV_DIR/Scripts/python.exe" "$VENV_DIR/bin/python.exe" "$VENV_DIR/bin/python"; do
        if [ -x "$candidate" ] && usable_python "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

ensure_venv() {
    [ -d "$VENV_DIR" ] && return 0
    if command -v uv >/dev/null 2>&1; then
        uv venv "$VENV_DIR" >/dev/null 2>&1 && return 0
    fi
    for base in python3 python; do
        command -v "$base" >/dev/null 2>&1 || continue
        if needs_native_python && ! is_native_python "$base"; then
            continue
        fi
        "$base" -m venv "$VENV_DIR" >/dev/null 2>&1 && return 0
    done
    return 1
}

PYTHON_BIN="${SKILL_LINKS_PYTHON:-}"
PYTHON_ARGS=""

if [ -z "$PYTHON_BIN" ]; then
    PYTHON_BIN="$(venv_python || true)"
fi

if [ -z "$PYTHON_BIN" ]; then
    ensure_venv || true
    PYTHON_BIN="$(venv_python || true)"
fi

if [ -z "$PYTHON_BIN" ]; then
    for candidate in python3 python; do
        if usable_python "$candidate"; then
            PYTHON_BIN="$candidate"
            break
        fi
    done
fi

if [ -z "$PYTHON_BIN" ] && command -v py >/dev/null 2>&1 && usable_python py; then
    PYTHON_BIN="py"
    PYTHON_ARGS="-3"
fi

if [ -z "$PYTHON_BIN" ]; then
    echo "error: 找不到可用的 Python 3（Windows 上必须是原生解释器）；" >&2
    echo "       装一个 Python，或用 SKILL_LINKS_PYTHON 指定解释器。" >&2
    exit 1
fi

if [ -n "$CATEGORIES" ]; then
    exec "$PYTHON_BIN" $PYTHON_ARGS "$CORE" \
        --repo "$SKILLS_DIR" --submodule "$SUBMODULE" --categories "$CATEGORIES" "$@"
fi
exec "$PYTHON_BIN" $PYTHON_ARGS "$CORE" --repo "$SKILLS_DIR" --submodule "$SUBMODULE" "$@"
