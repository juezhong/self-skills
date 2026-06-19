#!/bin/bash
set -euo pipefail

# 脚本位置: ~/.agents/skills/scripts/
# 作用: 为 agent-toolkit 子模块创建技能软链接、更新 .gitignore
# 前提: 子模块应已通过 git submodule update --init 就绪
#
# 用法:
#   ./scripts/link-agent-toolkit.sh              # 全量刷新：链接所有技能
#   ./scripts/link-agent-toolkit.sh skill-a      # 增量追加：只链接指定技能
#   ./scripts/link-agent-toolkit.sh --unlink     # 反向：取消所有软链接，删除 gitignore 区块

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SKILLS_DIR"

SUBMODULE_PATH="submodules/agent-toolkit"
INNER_BEGIN="# --- agent-toolkit begin ---"
INNER_END="# --- agent-toolkit end ---"

# ---- 反向操作：取消链接 ----
if [ "${1:-}" = "--unlink" ]; then
    echo "=== 取消软链接 ==="
    removed=0
    GITIGNORE="$SKILLS_DIR/.gitignore"
    if [ -f "$GITIGNORE" ] && grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        skills=$(sed -n "/$INNER_BEGIN/,/$INNER_END/p" "$GITIGNORE" | grep -v '^#')
        for skill in $skills; do
            if [ -L "$skill" ]; then
                target=$(readlink "$skill")
                if [[ "$target" == submodules/agent-toolkit/* ]]; then
                    rm "$skill"
                    removed=$((removed + 1))
                    echo "  已删除 $skill"
                fi
            fi
        done
    fi
    if [ $removed -eq 0 ] && [ -d "$SUBMODULE_PATH/skills" ]; then
        echo "  gitignore 中无记录，扫描子模块目录..."
        for dir in "$SUBMODULE_PATH/skills"/*/; do
            name="$(basename "$dir")"
            if [ -L "$name" ]; then
                target=$(readlink "$name")
                if [[ "$target" == submodules/agent-toolkit/* ]]; then
                    rm "$name"
                    removed=$((removed + 1))
                    echo "  已删除 $name"
                fi
            fi
        done
    fi
    echo "  共删除 ${removed} 个软链接"

    echo ""
    echo "=== 清理 .gitignore ==="
    if [ -f "$GITIGNORE" ] && grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        sed -i '' "/$INNER_BEGIN/,/$INNER_END/d" "$GITIGNORE"
        echo "  已删除 agent-toolkit 区块"
    fi
    echo ""
    echo "=== 完成 ==="
    exit 0
fi

is_skill_dir() { [ -d "$1" ] && [ -f "$1/SKILL.md" ]; }

if [ ! -d "$SUBMODULE_PATH/skills" ]; then
    echo "错误: 子模块未初始化，请先执行: git submodule update --init $SUBMODULE_PATH"
    exit 1
fi

if [ $# -eq 0 ]; then
    MODE="full"
else
    MODE="selective"
fi

echo "=== 创建软链接（模式: $MODE）==="

SKILL_NAMES=()
SUBMODULE_SKILLS="submodules/agent-toolkit/skills"

# ---- 全量模式 ----
if [ "$MODE" = "full" ]; then
    for dir in "$SUBMODULE_SKILLS"/*/; do
        is_skill_dir "$dir" || continue
        name="$(basename "$dir")"
        if [ -e "$name" ] || [ -L "$name" ]; then
            rm -rf "$name"
        fi
        ln -s "$dir" "$name"
        SKILL_NAMES+=("$name")
        echo "  $name -> $dir"
    done
fi

# ---- 选择性模式 ----
if [ "$MODE" = "selective" ]; then
    for skill in "$@"; do
        skill_dir="$SUBMODULE_SKILLS/${skill}"
        if ! is_skill_dir "$skill_dir"; then
            echo "  错误: 技能 '$skill' 在子模块中不存在，跳过"
            continue
        fi
        if [ -e "$skill" ] || [ -L "$skill" ]; then
            rm -rf "$skill"
        fi
        ln -s "$skill_dir" "$skill"
        SKILL_NAMES+=("$skill")
        echo "  $skill -> $skill_dir"
    done
fi

echo ""
echo "=== 更新 .gitignore ==="

GITIGNORE="$SKILLS_DIR/.gitignore"

OUTER_BEGIN="# === 技能软链接 begin ==="
OUTER_END="# === 技能软链接 end ==="

if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
fi

if ! grep -qF "$OUTER_BEGIN" "$GITIGNORE"; then
    echo "" >> "$GITIGNORE"
    echo "$OUTER_BEGIN" >> "$GITIGNORE"
    echo "$OUTER_END" >> "$GITIGNORE"
fi

outer_start=$(grep -nF "$OUTER_BEGIN" "$GITIGNORE" | head -1 | cut -d: -f1)
outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)

# ---- 全量模式：删除旧 block，重建 ----
if [ "$MODE" = "full" ]; then
    if grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        sed -i '' "/$INNER_BEGIN/,/$INNER_END/d" "$GITIGNORE"
    fi
    outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
    tmpfile=$(mktemp)
    { echo "$INNER_BEGIN"; printf '%s\n' "${SKILL_NAMES[@]}" | sort; echo "$INNER_END"; } > "$tmpfile"
    sed -i '' "$((outer_end - 1))r $tmpfile" "$GITIGNORE"
    rm -f "$tmpfile"
    echo "  已将 ${#SKILL_NAMES[@]} 个技能名写入 .gitignore"
fi

# ---- 选择性模式：定位 INNER_END 行号，直接插入 ----
if [ "$MODE" = "selective" ]; then
    if ! grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
        tmpfile=$(mktemp)
        printf '%s\n' "$INNER_BEGIN" "$INNER_END" > "$tmpfile"
        sed -i '' "$((outer_end - 1))r $tmpfile" "$GITIGNORE"
        rm -f "$tmpfile"
    fi

    added=0
    for skill in "${SKILL_NAMES[@]}"; do
        if sed -n "/$INNER_BEGIN/,/$INNER_END/p" "$GITIGNORE" | grep -qxF "$skill"; then
            echo "  [已存在] $skill，跳过"
            continue
        fi
        end_line=$(grep -nF "$INNER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
        sed -i '' "${end_line}i\\
$skill
" "$GITIGNORE"
        added=$((added + 1))
    done
    echo "  新增 ${added} 个技能名写入 .gitignore"
fi

echo ""
echo "=== 完成 ==="
echo "已创建软链接："
ls -la "$SKILLS_DIR" | grep '^l' | awk '{print "  " $NF}'
