#!/usr/bin/env bash
# 把所有子模块拉到上游指定分支的最新提交，并自动提交指针变化。
#
# 用法:
#   scripts/update-submodules.sh              # 拉 origin/main
#   scripts/update-submodules.sh --branch dev # 拉 origin/dev
#   scripts/update-submodules.sh --dry-run    # 只报告，不切换也不提交
#
# 行为:
#   1. 同步 .gitmodules 里的 URL 并初始化缺失的子模块
#   2. 对每个子模块 fetch origin，checkout 到 <branch> 并快进到 origin/<branch>
#   3. 父仓库中出现指针变化的子模块会被 git add 并提交
#   4. 没有变化时不做任何提交
#
# 兼容 macOS 自带 bash 3.2：不使用数组和 mapfile。
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"

BRANCH="main"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)
      [ $# -ge 2 ] || { echo "--branch 需要一个参数" >&2; exit 2; }
      BRANCH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -f .gitmodules ]; then
  echo "当前仓库没有 .gitmodules，无事可做。"
  exit 0
fi

echo "工作区: $WS"
echo "目标分支: origin/$BRANCH"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "模式: dry-run（不切换、不提交）"
fi
echo

git submodule sync --recursive >/dev/null
git submodule update --init --recursive >/dev/null

PATHS="$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')"
if [ -z "$PATHS" ]; then
  echo "未找到子模块。"
  exit 0
fi

BUMPED=""
SKIPPED=""

for path in $PATHS; do
  if [ ! -e "$path/.git" ]; then
    echo "=== $path ==="
    echo "  跳过: 目录不存在或不完整"
    SKIPPED="$SKIPPED$path (missing)"$'\n'
    continue
  fi

  echo "=== $path ==="

  if ! git -C "$path" fetch --tags --prune origin >/dev/null 2>&1; then
    echo "  跳过: fetch 失败（网络或远端不可用）"
    SKIPPED="$SKIPPED$path (fetch failed)"$'\n'
    continue
  fi

  if ! git -C "$path" rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
    echo "  跳过: 上游没有 origin/$BRANCH 分支"
    SKIPPED="$SKIPPED$path (no origin/$BRANCH)"$'\n'
    continue
  fi

  target="$(git -C "$path" rev-parse "origin/$BRANCH")"
  current="$(git -C "$path" rev-parse HEAD)"

  if [ "$current" = "$target" ]; then
    echo "  已是最新: ${target:0:12}"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  可更新: ${current:0:12} -> ${target:0:12}"
    BUMPED="$BUMPED$path"$'\n'
    continue
  fi

  git -C "$path" checkout --quiet -B "$BRANCH" "$target"
  echo "  已更新: ${current:0:12} -> ${target:0:12}"
  BUMPED="$BUMPED$path"$'\n'
done

echo

if [ -z "$BUMPED" ]; then
  echo "没有子模块需要更新。"
  if [ -n "$SKIPPED" ]; then
    echo "跳过:"
    printf '%s' "$SKIPPED" | sed 's/^/  - /'
  fi
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run 结束，以下子模块可更新（未做任何改动）:"
  printf '%s' "$BUMPED" | sed 's/^/  - /'
  exit 0
fi

# shellcheck disable=SC2086
git add -- $BUMPED

if git diff --cached --quiet; then
  echo "指针无实际变化，不提交。"
  exit 0
fi

commit_msg="chore(submodules): bump to upstream $BRANCH"$'\n'
printf '%s' "$BUMPED" | while IFS= read -r p; do
  [ -n "$p" ] && printf -- '- %s\n' "$p"
done > /tmp/.update-submodules-body.$$
commit_msg="$commit_msg"$'\n'"$(cat /tmp/.update-submodules-body.$$)"
rm -f /tmp/.update-submodules-body.$$

if ! git commit -m "$commit_msg" >/dev/null; then
  echo "提交失败，改动已暂存，请手动检查后重新提交。" >&2
  exit 1
fi

echo "已提交:"
git log -1 --format='  %h %s'
printf '%s' "$BUMPED" | sed 's/^/  - /'

if [ -n "$SKIPPED" ]; then
  echo
  echo "跳过:"
  printf '%s' "$SKIPPED" | sed 's/^/  - /'
fi
