#!/bin/bash
set -euo pipefail

# 脚本位置: ~/.agents/skills/scripts/
# 作用: 为 mattpocock-skills 子模块创建技能软链接、更新 .gitignore
# 前提: 子模块应已通过 git submodule update --init 就绪
#
# 用法:
#   ./scripts/link-mattpocock-skills.sh              # 全量刷新：链接所有技能
#   ./scripts/link-mattpocock-skills.sh skill-a      # 增量追加：只链接指定技能
#   ./scripts/link-mattpocock-skills.sh --unlink     # 反向：取消所有软链接，删除 gitignore 区块

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SKILLS_DIR"

SUBMODULE_PATH="submodules/mattpocock-skills"
INNER_BEGIN="# --- mattpocock-skills begin ---"
INNER_END="# --- mattpocock-skills end ---"

# ---- 反向操作：取消链接 ----
if [ "${1:-}" = "--unlink" ]; then
    echo "=== 取消软链接 ==="
    removed=0
    # 从 gitignore 读取这个子模块的技能列表
    GITIGNORE="$SKILLS_DIR/.gitignore"
    if [ -f "$GITIGNORE" ] && grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        skills=$(sed -n "/$INNER_BEGIN/,/$INNER_END/p" "$GITIGNORE" | grep -v '^#')
        for skill in $skills; do
            if [ -L "$skill" ]; then
                # 确认软链接指向这个子模块
                target=$(readlink "$skill")
                if [[ "$target" == submodules/mattpocock-skills/* ]]; then
                    rm "$skill"
                    removed=$((removed + 1))
                    echo "  已删除 $skill"
                fi
            fi
        done
    fi
    # 如果 gitignore 中没有，则扫描子模块目录
    if [ $removed -eq 0 ] && [ -d "$SUBMODULE_PATH/skills" ]; then
        echo "  gitignore 中无记录，扫描子模块目录..."
        for category in engineering productivity; do
            sub_path="$SUBMODULE_PATH/skills/${category}"
            [ -d "$sub_path" ] || continue
            for dir in "$sub_path"/*/; do
                name="$(basename "$dir")"
                if [ -L "$name" ]; then
                    target=$(readlink "$name")
                    if [[ "$target" == submodules/mattpocock-skills/* ]]; then
                        rm "$name"
                        removed=$((removed + 1))
                        echo "  已删除 $name"
                    fi
                fi
            done
        done
    fi
    echo "  共删除 ${removed} 个软链接"

    echo ""
    echo "=== 清理 .gitignore ==="
    if [ -f "$GITIGNORE" ] && grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        sed -i '' "/$INNER_BEGIN/,/$INNER_END/d" "$GITIGNORE"
        echo "  已删除 mattpocock-skills 区块"
    fi
    echo ""
    echo "=== 完成 ==="
    exit 0
fi

# 检查子模块是否就绪
# 判定技能目录的标准：同时满足【是目录】且【包含 SKILL.md】
is_skill_dir() { [ -d "$1" ] && [ -f "$1/SKILL.md" ]; }

if [ ! -d "$SUBMODULE_PATH/skills" ]; then
    echo "错误: 子模块未初始化，请先执行: git submodule update --init $SUBMODULE_PATH"
    exit 1
fi

# 判定模式
if [ $# -eq 0 ]; then
    MODE="full"
else
    MODE="selective"
fi

echo "=== 创建软链接（模式: $MODE）==="

SKILL_NAMES=()

# ---- 全量模式：扫描子模块所有技能 ----
if [ "$MODE" = "full" ]; then
    link_skills() {
        local category="$1"
        local sub_path="submodules/mattpocock-skills/skills/${category}"

        if [ ! -d "$sub_path" ]; then
            echo "  [跳过] $category 目录不存在: $sub_path"
            return
        fi

        for dir in "$sub_path"/*/; do
            is_skill_dir "$dir" || continue
            local name
            name="$(basename "$dir")"

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
fi

# ---- 选择性模式：只链接指定技能 ----
if [ "$MODE" = "selective" ]; then
    # 先收集子模块中所有可用技能（用于校验）
    ALL_AVAILABLE=()
    for category in engineering productivity; do
        sub_path="submodules/mattpocock-skills/skills/${category}"
        if [ -d "$sub_path" ]; then
            for dir in "$sub_path"/*/; do
                is_skill_dir "$dir" || continue
                ALL_AVAILABLE+=("$(basename "$dir")")
            done
        fi
    done

    for skill in "$@"; do
        # 校验技能是否存在
        found=false
        for available in "${ALL_AVAILABLE[@]}"; do
            if [ "$skill" = "$available" ]; then
                found=true
                break
            fi
        done
        if ! $found; then
            echo "  错误: 技能 '$skill' 在子模块中不存在，跳过"
            continue
        fi

        # 找到技能的实际路径
        for category in engineering productivity; do
            skill_dir="submodules/mattpocock-skills/skills/${category}/${skill}"
            if is_skill_dir "$skill_dir"; then
                if [ -e "$skill" ] || [ -L "$skill" ]; then
                    rm -rf "$skill"
                fi
                ln -s "$skill_dir" "$skill"
                SKILL_NAMES+=("$skill")
                echo "  $skill -> $skill_dir"
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

if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
fi

# 确保外层区块存在
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
    {
        echo "$INNER_BEGIN"
        printf '%s\n' "${SKILL_NAMES[@]}" | sort
        echo "$INNER_END"
    } > "$tmpfile"
    sed -i '' "$((outer_end - 1))r $tmpfile" "$GITIGNORE"
    rm -f "$tmpfile"
    echo "  已将 ${#SKILL_NAMES[@]} 个技能名写入 .gitignore"
fi

# ---- 选择性模式：定位 INNER_END 行号，直接插入 ----
if [ "$MODE" = "selective" ]; then
    # 如果 inner block 不存在，先创建空框架
    if ! grep -qF "$INNER_BEGIN" "$GITIGNORE"; then
        outer_end=$(grep -nF "$OUTER_END" "$GITIGNORE" | head -1 | cut -d: -f1)
        tmpfile=$(mktemp)
        printf '%s\n' "$INNER_BEGIN" "$INNER_END" > "$tmpfile"
        sed -i '' "$((outer_end - 1))r $tmpfile" "$GITIGNORE"
        rm -f "$tmpfile"
    fi

    added=0
    for skill in "${SKILL_NAMES[@]}"; do
        # 跳过已存在的
        if sed -n "/$INNER_BEGIN/,/$INNER_END/p" "$GITIGNORE" | grep -qxF "$skill"; then
            echo "  [已存在] $skill，跳过"
            continue
        fi
        # 定位 INNER_END 行号，在它前面插入
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
