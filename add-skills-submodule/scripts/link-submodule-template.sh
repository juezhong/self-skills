#!/bin/bash
set -euo pipefail

# 模板：为新子模块创建技能软链接、更新 .gitignore
# 使用方法：全局替换 __SUBMODULE_NAME__，根据需要选择扁平/分类模式
#
# 用法:
#   ./scripts/link-__SUBMODULE_NAME__.sh              # 全量刷新
#   ./scripts/link-__SUBMODULE_NAME__.sh skill-a      # 增量追加
#   ./scripts/link-__SUBMODULE_NAME__.sh --unlink     # 反向：取消链接

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SKILLS_DIR"

SUBMODULE_PATH="submodules/__SUBMODULE_NAME__"
INNER_BEGIN="# --- __SUBMODULE_NAME__ begin ---"
INNER_END="# --- __SUBMODULE_NAME__ end ---"

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
                if [[ "$target" == submodules/__SUBMODULE_NAME__/* ]]; then
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
                if [[ "$target" == submodules/__SUBMODULE_NAME__/* ]]; then
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
        echo "  已删除 __SUBMODULE_NAME__ 区块"
    fi
    echo ""
    echo "=== 完成 ==="
    exit 0
fi

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

# ═══════════════════════════════════════════════════════
# 模式 A：扁平结构（skills/ 下直接是技能目录）
# 示例：agent-toolkit
# ═══════════════════════════════════════════════════════
# SUBMODULE_SKILLS="submodules/__SUBMODULE_NAME__/skills"
#
# if [ "$MODE" = "full" ]; then
#     for dir in "$SUBMODULE_SKILLS"/*/; do
#         name="$(basename "$dir")"
#         if [ -e "$name" ] || [ -L "$name" ]; then rm -rf "$name"; fi
#         ln -s "$dir" "$name"; SKILL_NAMES+=("$name"); echo "  $name -> $dir"
#     done
# fi
#
# if [ "$MODE" = "selective" ]; then
#     for skill in "$@"; do
#         skill_dir="$SUBMODULE_SKILLS/${skill}"
#         if [ ! -d "$skill_dir" ]; then echo "  错误: 技能 '$skill' 不存在，跳过"; continue; fi
#         if [ -e "$skill" ] || [ -L "$skill" ]; then rm -rf "$skill"; fi
#         ln -s "$skill_dir" "$skill"; SKILL_NAMES+=("$skill"); echo "  $skill -> $skill_dir"
#     done
# fi

# ═══════════════════════════════════════════════════════
# 模式 B：分类结构（skills/engineering/、skills/productivity/ 等）
# 示例：mattpocock-skills
# ═══════════════════════════════════════════════════════
SUBMODULE_SKILLS="submodules/__SUBMODULE_NAME__/skills"

if [ "$MODE" = "full" ]; then
    link_skills() {
        local category="$1"
        local sub_path="${SUBMODULE_SKILLS}/${category}"
        if [ ! -d "$sub_path" ]; then echo "  [跳过] $category"; return; fi
        for dir in "$sub_path"/*/; do
            local name; name="$(basename "$dir")"
            if [ -e "$name" ] || [ -L "$name" ]; then rm -rf "$name"; fi
            ln -s "$dir" "$name"; SKILL_NAMES+=("$name"); echo "  $name -> $dir"
        done
    }
    link_skills "engineering"
    link_skills "productivity"
fi

if [ "$MODE" = "selective" ]; then
    # 先收集所有可用技能（用于校验）
    ALL_AVAILABLE=()
    for category in engineering productivity; do
        sub_path="${SUBMODULE_SKILLS}/${category}"
        if [ -d "$sub_path" ]; then
            for dir in "$sub_path"/*/; do ALL_AVAILABLE+=("$(basename "$dir")"); done
        fi
    done
    for skill in "$@"; do
        found=false
        for a in "${ALL_AVAILABLE[@]}"; do if [ "$skill" = "$a" ]; then found=true; break; fi; done
        if ! $found; then echo "  错误: 技能 '$skill' 不存在，跳过"; continue; fi
        for category in engineering productivity; do
            skill_dir="${SUBMODULE_SKILLS}/${category}/${skill}"
            if [ -d "$skill_dir" ]; then
                if [ -e "$skill" ] || [ -L "$skill" ]; then rm -rf "$skill"; fi
                ln -s "$skill_dir" "$skill"; SKILL_NAMES+=("$skill"); echo "  $skill -> $skill_dir"
                break
            fi
        done
    done
fi

echo ""
echo "=== 更新 .gitignore ==="

GITIGNORE="$SKILLS_DIR/.gitignore"

OUTER_BEGIN="# === 技能软链接 begin ==="
OUTER_END="# === 技能软链接 end ==="

if [ ! -f "$GITIGNORE" ]; then touch "$GITIGNORE"; fi

if ! grep -qF "$OUTER_BEGIN" "$GITIGNORE"; then
    echo "" >> "$GITIGNORE"
    echo "$OUTER_BEGIN" >> "$GITIGNORE"
    echo "$OUTER_END" >> "$GITIGNORE"
fi

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