#!/usr/bin/env bash
# 入口：为 mattpocock-skills 子模块建立技能链接。
#
# 链接逻辑全部在 scripts/skill_links.py：MSYS 下走 junction，真 Unix 走相对
# 软链接，路径统一转成 Windows 可解析的形式。这里只负责挑一个解释器并转交。
#
# Windows（MSYS/Cygwin/bash）只接受原生 Windows 解释器：以 os.sep 是反斜杠
# 为判据。POSIX 版 Python 会把链接目标写成正斜杠，Windows 不解析这类重解析点。
# 没有可用解释器时先建 .venv，优先用 uv。
set -euo pipefail

case "$0" in
    */*) SCRIPT_DIR="${0%/*}" ;;
    *) SCRIPT_DIR="." ;;
esac
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
SKILLS_DIR="${SCRIPT_DIR%/*}"
SUBMODULE="mattpocock-skills"
CATEGORIES="engineering,productivity"
VENV_DIR="$SKILLS_DIR/.venv"

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

exec "$PYTHON_BIN" $PYTHON_ARGS "$SCRIPT_DIR/skill_links.py" \
    --repo "$SKILLS_DIR" --submodule "$SUBMODULE" --categories "$CATEGORIES" "$@"
