#!/usr/bin/env bash
# 构建 Reasonix CLI 二进制 (GOOS=android GOARCH=arm64, 静态)
#
# 用法:
#   build-reasonix.sh <upstream_tag> <source_dir> <output_dir>
#
# 例:
#   build-reasonix.sh v1.19.7 ./upstream ./build
set -euo pipefail

TAG="${1:?missing upstream_tag}"
SRC_DIR="${2:?missing source_dir}"
OUT_DIR="${3:?missing output_dir}"

mkdir -p "$OUT_DIR"

VER="${TAG#v}"
COMMIT=$(git -C "$SRC_DIR" rev-parse --short HEAD)

echo "::group::go build (GOOS=android GOARCH=arm64 CGO_ENABLED=0)"
# 用户要求 GOOS=android GOARCH=arm64
# CGO_ENABLED=0 -> 纯静态 ELF, Termux (bionic libc) 可直接运行
# 若未来 Go 拒绝 GOOS=android + CGO_ENABLED=0, 回退 GOOS=linux GOARCH=arm64 (Termux 兼容)
if ! (cd "$SRC_DIR" && \
  CGO_ENABLED=0 GOOS=android GOARCH=arm64 \
  go build \
    -trimpath \
    -ldflags "-s -w -X main.version=${TAG} -X reasonix/internal/productdocs.linkedVersion=${TAG} -X reasonix/internal/productdocs.linkedRevision=${COMMIT}" \
    -o "$(pwd)/$OUT_DIR/reasonix" \
    ./cmd/reasonix); then
  echo "::warning::GOOS=android build failed, falling back to GOOS=linux (still runs on Termux)"
  (cd "$SRC_DIR" && \
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build \
      -trimpath \
      -ldflags "-s -w -X main.version=${TAG} -X reasonix/internal/productdocs.linkedVersion=${TAG} -X reasonix/internal/productdocs.linkedRevision=${COMMIT}" \
      -o "$(pwd)/$OUT_DIR/reasonix" \
      ./cmd/reasonix)
fi
echo "::endgroup::"

echo "Built: $OUT_DIR/reasonix"
file "$OUT_DIR/reasonix"
ls -lh "$OUT_DIR/reasonix"
