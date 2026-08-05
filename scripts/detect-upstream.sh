#!/usr/bin/env bash
# 检测 esengine/DeepSeek-Reasonix 上游最新 CLI tag
# 输出: 上游 tag (例: v1.19.7) 到 stdout
# 退出码: 0=成功, 1=失败
set -euo pipefail

UPSTREAM_REPO="esengine/DeepSeek-Reasonix"

# GitHub API 列出最近 20 个 release (含 CLI 和 Desktop, 按时间倒序)
# 过滤掉:
#   - prerelease (预发布)
#   - desktop-* 开头的 tag (Desktop 版, 我们只跟 CLI)
#   - npm-* 开头的 tag (npm 包, 同上)
# 取第一个匹配的 (即最新的 CLI stable release)
#
# 注意: 不能用 /releases/latest 端点, 那会返回最新创建的 release
# (可能是 desktop-v*, npm-v*, 而不是 CLI v*)
TAG=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: termux-sync-bot" \
  "https://api.github.com/repos/${UPSTREAM_REPO}/releases?per_page=20" \
  | jq -r '[.[] | select(.prerelease == false and (.tag_name | test("^(desktop|npm)-") | not))][0].tag_name // empty')

if [ -z "$TAG" ]; then
  echo "ERROR: could not resolve upstream latest CLI tag" >&2
  exit 1
fi

echo "$TAG"
