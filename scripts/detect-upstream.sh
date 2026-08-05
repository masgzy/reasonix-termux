#!/usr/bin/env bash
# 检测 esengine/DeepSeek-Reasonix 上游最新 CLI tag
# 输出: 上游 tag (例: v1.19.7) 到 stdout
# 退出码: 0=成功, 1=失败
set -euo pipefail

UPSTREAM_REPO="esengine/DeepSeek-Reasonix"

TAG=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" \
  | jq -r '.tag_name // empty')

if [ -z "$TAG" ]; then
  echo "ERROR: could not resolve upstream latest tag" >&2
  exit 1
fi

echo "$TAG"
