#!/usr/bin/env bash
# 兼容入口：实际的链接和 .gitignore 管理由 Python 脚本完成。
set -euo pipefail

# -h/--help 不需要创建虚拟环境，直接显示用法即可。
case "${1:-}" in
    -h|--help)
        cat <<'EOF'
用法:
  ./scripts/link-mattpocock-skills.sh             # 链接所有已推广技能
  ./scripts/link-mattpocock-skills.sh --unlink    # 仅删除本脚本创建的技能软链接

说明:
  - 全量链接前如已有同名路径，请先执行 --unlink。
  - --unlink 不会修改 .gitignore。
  - 脚本优先使用 uv 创建 .venv；没有 uv 时使用 python3 -m venv。
EOF
        exit 0
        ;;
esac

# 根据脚本位置定位仓库根目录，避免依赖调用时所在的工作目录。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$SKILLS_DIR/.venv"

# 当前仓库没有虚拟环境时，优先用 uv 创建；失败或未安装 uv 时回退到标准库 venv。
if [ ! -x "$VENV_DIR/bin/python" ]; then
    echo "Creating virtual environment: $VENV_DIR"
    if command -v uv >/dev/null 2>&1; then
        if ! uv venv "$VENV_DIR"; then
            echo "uv could not create the virtual environment; falling back to python3 -m venv." >&2
            python3 -m venv "$VENV_DIR"
        fi
    else
        python3 -m venv "$VENV_DIR"
    fi
fi

# 显式使用本仓库的虚拟环境解释器运行 Python 实现。
export VIRTUAL_ENV="$VENV_DIR"
export PATH="$VENV_DIR/bin:$PATH"
exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/link-mattpocock-skills.py" "$@"
