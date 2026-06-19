---
name: add-skills-submodule
description: Add a new git submodule for skills and create its link script. Use when user asks to add a skills repository as a submodule, or says "新增子模块", "加入子模块", "引入技能仓库", "add submodule".
---

# Add skills submodule

将新的技能仓库添加为 git 子模块，并创建对应的 link 脚本。

## 流程

### 1. 添加子模块

```bash
git submodule add <url> submodules/<name>
```

### 2. 查看 skills 结构

确认 `submodules/<name>/skills/` 下的目录结构：

| 结构 | 特征 | 遍历方式 |
|------|------|----------|
| **扁平** | `skills/` 下直接是技能目录 | `for dir in submodules/<name>/skills/*/` |
| **分类** | `skills/engineering/`、`skills/productivity/` 等 | 复用 `link_skills()` 函数逐类遍历 |

### 3. 复制模板脚本

```bash
cp add-skills-submodule/scripts/link-submodule-template.sh scripts/link-<name>.sh
```

### 4. 适配脚本

**全局替换** `__SUBMODULE_NAME__` → 实际子模块名。

**选择技能遍历模式（模板中已包含两种）：**

- **扁平**（默认已启用）：适用于 `skills/` 下直接是技能目录的情况，如 `agent-toolkit`
- **分类**：适用于 `skills/engineering/`、`skills/productivity/` 等分组结构。将模板中模式 A 注释掉，取消模式 B 的注释

### 5. 运行脚本

三种模式：

```bash
./scripts/link-<name>.sh              # 全量刷新：链接子模块所有技能
./scripts/link-<name>.sh skill-a      # 增量追加：只链接指定技能
./scripts/link-<name>.sh --unlink     # 反向：取消所有软链接，删除 gitignore 区块
```

| 模式 | 触发 | 行为 | gitignore |
|------|------|------|-----------|
| 全量 | 无参数 | 扫描子模块全部技能，全量重建 | 重建整个 inner block |
| 增量 | 带参数 | 仅链接指定技能（不存在则报错跳过） | 定位 INNER_END 行，在前面插入 |
| 反向 | `--unlink` | 取消所有软链接 + 删除 inner block | 范围删除 inner block |

脚本会自动：
- 检查子模块是否已初始化（未初始化则报错提示，`--unlink` 除外）
- 创建项目根目录下的技能软链接
- 更新 `.gitignore`（追加子区块到统一托管块，不影响其他子模块）

### 6. 验证

```bash
git status   # 软链接应被 gitignore 忽略，不出现
```

## .gitignore 结构

所有 `link-*.sh` 共用同一个托管区块，互不干扰：

```gitignore
# === 技能软链接 begin ===
# --- mattpocock-skills begin ---
ask-matt
codebase-design
...
# --- mattpocock-skills end ---
# --- agent-toolkit begin ---
agent-md-refactor
...
# --- agent-toolkit end ---
# === 技能软链接 end ===
```

每个脚本只管理自己的 inner block（`# --- <name> begin ---` 到 `# --- <name> end ---`），运行时删除旧 block、插入新 block，其他子模块的条目不受影响。

## 注意事项

- 子模块初始化 `git submodule update --init` 由用户单独执行，脚本只检查、不自动 init
- 新技能名称如与已有软链接同名，脚本会用新链接覆盖旧链接（先 rm 再 ln）
- 脚本基于 bash 3.2（macOS 默认），不要用 `declare -A` 等 bash 4+ 特性
