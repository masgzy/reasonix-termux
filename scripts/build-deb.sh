#!/usr/bin/env bash
# 把 Reasonix 二进制打包成 Termux 兼容的 .deb 包
#
# 用法:
#   build-deb.sh <upstream_tag> <termux_arch> <termux_prefix> <binary_path> <output_dir>
#
# 例:
#   build-deb.sh v1.19.7 aarch64 /data/data/com.termux/files/usr ./build/reasonix ./build
#
# 产物: <output_dir>/reasonix_<version>_<arch>.deb
set -euo pipefail

TAG="${1:?missing upstream_tag}"
ARCH="${2:?missing termux_arch}"        # aarch64
PREFIX="${3:?missing termux_prefix}"    # /data/data/com.termux/files/usr
BIN_PATH="${4:?missing binary_path}"
OUT_DIR="${5:?missing output_dir}"

VER="${TAG#v}"
PKG_NAME="reasonix"
FULL_VER="${VER}"
DEB_NAME="${PKG_NAME}_${FULL_VER}_${ARCH}.deb"

WORK_DIR="$(mktemp -d)"
trap "rm -rf $WORK_DIR" EXIT

# ----------------------------------------------------------------------
# 1. 数据目录 (data.tar.gz) - 实际安装到系统的文件
# ----------------------------------------------------------------------
# .deb 内部路径相对根 /, 所以要用完整的 $PREFIX 路径
DATA_DIR="$WORK_DIR/data"
INSTALL_DIR="$DATA_DIR${PREFIX}/bin"
DOC_DIR="$DATA_DIR${PREFIX}/share/doc/${PKG_NAME}"
MAN_DIR="$DATA_DIR${PREFIX}/share/man/man1"

mkdir -p "$INSTALL_DIR" "$DOC_DIR" "$MAN_DIR"

# 拷贝二进制
cp "$BIN_PATH" "$INSTALL_DIR/${PKG_NAME}"
chmod 0755 "$INSTALL_DIR/${PKG_NAME}"

# 简易 man page
cat > "$MAN_DIR/${PKG_NAME}.1" <<EOF
.TH REASONIX 1 "$(date +%Y-%m-%d)" "${FULL_VER}" "Reasonix CLI"
.SH NAME
reasonix \- DeepSeek-native AI coding agent for the terminal
.SH SYNOPSIS
.B reasonix
[\fIflags\fR] [\fIcommand\fR]
.SH DESCRIPTION
Reasonix is a cache-first DeepSeek AI coding agent.
Built for Termux (aarch64, GOOS=android).
.SH SEE ALSO
https://github.com/esengine/DeepSeek-Reasonix
EOF
gzip -9n "$MAN_DIR/${PKG_NAME}.1"

# changelog
cat > "$DOC_DIR/changelog.Debian" <<EOF
reasonix (${FULL_VER}) stable; urgency=medium

  * Repackaged for Termux from upstream ${TAG}.
  * Built with GOOS=android GOARCH=arm64 CGO_ENABLED=0.

 -- Termux auto-publisher <noreply@github.com>  $(date -R)
EOF
gzip -9n "$DOC_DIR/changelog.Debian"

# copyright
cat > "$DOC_DIR/copyright" <<EOF
Copyright: See upstream project.
Upstream: https://github.com/esengine/DeepSeek-Reasonix
License:  See upstream LICENSE file.
EOF

# ----------------------------------------------------------------------
# 2. 控制目录 (control.tar.gz) - deb 元数据 + 维护脚本
# ----------------------------------------------------------------------
CTRL_DIR="$WORK_DIR/control"
mkdir -p "$CTRL_DIR"

INSTALLED_SIZE=$(du -sk "$DATA_DIR" | awk '{print $1}')

cat > "$CTRL_DIR/control" <<EOF
Package: ${PKG_NAME}
Version: ${FULL_VER}
Architecture: ${ARCH}
Maintainer: Termux auto-publisher <noreply@github.com>
Installed-Size: ${INSTALLED_SIZE}
Depends:
Recommends:
Conflicts: reasonix-static
Replaces: reasonix-static
Section: utils
Priority: optional
Homepage: https://github.com/esengine/DeepSeek-Reasonix
Description: DeepSeek-native AI coding agent for the terminal (Termux build)
 Cache-first CLI built for Android/Termux from upstream ${TAG}.
 .
 Built with GOOS=android GOARCH=arm64 CGO_ENABLED=0 (static ELF).
EOF

# postinst - 安装后修复权限 / 更新 mandb
cat > "$CTRL_DIR/postinst" <<'EOF'
#!/bin/sh
set -e
# 确保 binary 可执行
chmod 0755 /data/data/com.termux/files/usr/bin/reasonix
# mandb (如果存在)
if command -v mandb >/dev/null 2>&1; then
  mandb -q 2>/dev/null || true
fi
echo "reasonix installed. Run 'reasonix --help' to get started."
exit 0
EOF
chmod 0755 "$CTRL_DIR/postinst"

# prerm - 删除前
cat > "$CTRL_DIR/prerm" <<'EOF'
#!/bin/sh
set -e
exit 0
EOF
chmod 0755 "$CTRL_DIR/prerm"

# ----------------------------------------------------------------------
# 3. 打包 .deb (ar 归档)
# ----------------------------------------------------------------------
# debian-binary
echo "2.0" > "$WORK_DIR/debian-binary"

# control.tar.gz
( cd "$CTRL_DIR" && tar czf "$WORK_DIR/control.tar.gz" . )

# data.tar.gz
( cd "$DATA_DIR" && tar czf "$WORK_DIR/data.tar.gz" . )

# .deb = ar 归档: debian-binary control.tar.gz data.tar.gz
DEB_PATH="$OUT_DIR/$DEB_NAME"
(
  cd "$WORK_DIR"
  # ar 魔术头 + 文件顺序: debian-binary, control.tar.gz, data.tar.gz
  ar rcs "$DEB_PATH" debian-binary control.tar.gz data.tar.gz
)

echo ""
echo "Built deb: $DEB_PATH"
ls -lh "$DEB_PATH"
echo ""
echo "Contents:"
ar t "$DEB_PATH"
echo ""
echo "Control file:"
ar p "$DEB_PATH" control.tar.gz | tar xzO ./control
