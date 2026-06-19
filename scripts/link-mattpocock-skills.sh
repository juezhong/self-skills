#!/bin/bash
set -euo pipefail

# 脚本位置: ~/.agents/skills/scripts/
# 作用: 为 mattpocock-skills 子模块创建技能软链接、更新 .gitignore
# 前提: 子模块应已通过 git submodule update --init 就绪

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SKILLS_DIR"

# 检查子模块是否就绪
SUBMODULE_PATH="submodules/mattpocock-skills"
if [ ! -d "$SUBMODULE_PATH/skills" ]; then
    echo "错误: 子模块未初始化，请先执行: git submodule update --init $SUBMODULE_PATH"
    exit 1
fi

echo "=== 创建软链接 ==="

# 收集所有技能名，用于后续更新 .gitignore
SKILL_NAMES=()

link_skills() {
    local category="$1"
    local sub_path="submodules/mattpocock-skills/skills/${category}"

    if [ ! -d "$sub_path" ]; then
        echo "  [跳过] $category 目录不存在: $sub_path"
        return
    fi

    for dir in "$sub_path"/*/; do
        local name
        name="$(basename "$dir")"

        # 如果已存在同名文件/链接，先删除
        if [ -e "$name" ] || [ -L "$name" ]; then
            rm -rf "$name"
        fi

        ln -s "$dir" "$name"
        SKILL_NAMES+=("$name")
        echo "  $name -> $dir"
    done
}

link_skills "engineering"
link_skills "productivity"

echo ""
echo "=== 更新 .gitignore ==="

GITIGNORE="$SKILLS_DIR/.gitignore"

# 结构：
#   # === 技能软链接 begin ===
#   # --- <submodule> begin ---
#   skill-a
#   skill-b
#   # --- <submodule> end ---
#   # === 技能软链接 end ===
#
# 每个 link-*.sh 只管自己子模块的 inner block，互不干扰。
OUTER_BEGIN="# === 技能软链接 begin ==="
OUTER_END="# === 技能软链接 end ==="
INNER_BEGIN="# --- mattpocock-skills begin ---"
INNER_END="# --- mattpocock-skills end ---"

# 如果 .gitignore 不存在则创建
if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
fi

# 如果外层区块不存在，先创建框架
if ! grep -qF "$OUTER_BEGIN" "$GITIGNORE"; then
    echo "" >> "$GITIGNORE"
    echo "$OUTER_BEGIN" >> "$GITIGNORE"
    echo "$OUTER_END" >> "$GITIGNORE"
fi

# 定位外层区块的行号
outer_start=$(grep -nF "$OUTER_BEGIN" "$GITIGNORE" | head -1 | cut -d: -f1)
outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)

# 如果自己的 inner 区块已存在，先删除
if grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
    inner_start=$(grep -nF "$INNER_BEGIN" "$GITIGNORE" | head -1 | cut -d: -f1)
    inner_end=$(grep -nF "$INNER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
    sed -i '' "${inner_start},${inner_end}d" "$GITIGNORE"
    # 修正 outer_end（行号因删除上移了）
    outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
fi

# 构建 inner 区块内容，写入临时文件
tmpfile=$(mktemp)
{
    echo "$INNER_BEGIN"
    printf '%s\n' "${SKILL_NAMES[@]}" | sort
    echo "$INNER_END"
} > "$tmpfile"

# 在 outer_end-1 行后插入（即 outer_end 之前）
sed -i '' "$((outer_end - 1))r $tmpfile" "$GITIGNORE"
rm -f "$tmpfile"

echo "  已将 ${#SKILL_NAMES[@]} 个技能名写入 .gitignore"

echo ""
echo "=== 完成 ==="
echo "已创建软链接："
ls -la "$SKILLS_DIR" | grep '^l' | awk '{print "  " $NF}'
