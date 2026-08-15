#!/usr/bin/env bash
# 把 .deb 包目录打包成 Termux 兼容的 apt 源结构
#
# 用法:
#   build-apt-repo.sh <deb_dir> <dist> <component> <arch> <out_dir>
#
# 例:
#   build-apt-repo.sh ./build stable main aarch64 ./apt-root
#
# 产物:
#   <out_dir>/dists/<dist>/<component>/binary-<arch>/Packages
#   <out_dir>/dists/<dist>/<component>/binary-<arch>/Packages.gz
#   <out_dir>/dists/<dist>/<component>/binary-<arch>/*.deb
#   <out_dir>/dists/<dist>/Release
set -euo pipefail

DEB_DIR="${1:?missing deb_dir}"
DIST="${2:?missing dist}"           # stable
COMPONENT="${3:?missing component}" # main
ARCH="${4:?missing arch}"           # aarch64
OUT_DIR="${5:?missing out_dir}"

# 转成绝对路径, 防止后续 cd 子shell 后相对路径失效
DEB_DIR="$(cd "$DEB_DIR" && pwd)"
OUT_DIR="$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)"

PKG_DIR="$OUT_DIR/dists/$DIST/$COMPONENT/binary-$ARCH"
mkdir -p "$PKG_DIR"

# 1. 拷贝所有 .deb 到 binary-<arch> 目录
shopt -s nullglob
DEBS=( "$DEB_DIR"/*.deb )
if [ ${#DEBS[@]} -eq 0 ]; then
  echo "ERROR: no .deb files found in $DEB_DIR" >&2
  exit 1
fi
for deb in "${DEBS[@]}"; do
  cp -v "$deb" "$PKG_DIR/"
done

# 2. 生成 Packages 索引
#    用 dpkg-scanpackages (Ubuntu runner 自带) - 简单可靠
echo "Generating Packages index..."
( cd "$OUT_DIR" && \
  dpkg-scanpackages --arch "$ARCH" --multiversion "dists/$DIST/$COMPONENT/binary-$ARCH" \
  > "dists/$DIST/$COMPONENT/binary-$ARCH/Packages" )

# 也生成 gzip 压缩版 (apt 会优先用 .gz / .xz / .zst)
gzip -9cn "$PKG_DIR/Packages" > "$PKG_DIR/Packages.gz"

# 3. 生成 Release 文件
#    包含: 元数据 + 所有文件的 SHA256/MD5/Size
echo "Generating Release file..."
RELEASE_FILE="$OUT_DIR/dists/$DIST/Release"

# 收集所有需要校验的文件 (相对 dists/$DIST 路径)
# 用 mktemp 避免并发构建时多个 job 写同一个 /tmp 文件冲突
FILES_LIST=$(mktemp)
RELEASE_TAIL=$(mktemp)
trap "rm -f \"$FILES_LIST\" \"$RELEASE_TAIL\"" EXIT
( cd "$OUT_DIR/dists/$DIST" && \
  find . -type f ! -name Release ! -name InRelease \
  | sed 's|^\./||' \
  | sort > "$FILES_LIST" )

# 生成 Release 头部
DATE=$(date -Ru)
cat > "$RELEASE_FILE" <<EOF
Origin: Reasonix Termux Repo
Label: reasonix-termux
Suite: $DIST
Codename: $DIST
Version: 1.0
Date: $DATE
Architectures: $ARCH
Components: $COMPONENT
Description: Auto-published Termux apt repository for Reasonix CLI (Android/aarch64)
EOF

# 追加 MD5/SHA1/SHA256 校验和
( cd "$OUT_DIR/dists/$DIST" && \
  echo "MD5Sum:" >> "$RELEASE_TAIL" && \
  while read -r f; do
    SIZE=$(stat -c '%s' "$f")
    MD5=$(md5sum "$f" | awk '{print $1}')
    printf " %s %16d %s\n" "$MD5" "$SIZE" "$f" >> "$RELEASE_TAIL"
  done < "$FILES_LIST" && \
  echo "SHA1:" >> "$RELEASE_TAIL" && \
  while read -r f; do
    SIZE=$(stat -c '%s' "$f")
    SHA1=$(sha1sum "$f" | awk '{print $1}')
    printf " %s %16d %s\n" "$SHA1" "$SIZE" "$f" >> "$RELEASE_TAIL"
  done < "$FILES_LIST" && \
  echo "SHA256:" >> "$RELEASE_TAIL" && \
  while read -r f; do
    SIZE=$(stat -c '%s' "$f")
    SHA256=$(sha256sum "$f" | awk '{print $1}')
    printf " %s %16d %s\n" "$SHA256" "$SIZE" "$f" >> "$RELEASE_TAIL"
  done < "$FILES_LIST"
)

cat "$RELEASE_TAIL" >> "$RELEASE_FILE"

echo ""
echo "Release file: $RELEASE_FILE"
cat "$RELEASE_FILE"

echo ""
echo "APT repo tree:"
find "$OUT_DIR" -type f | sort
