# Reasonix Termux APT 源 (自动发布)

最新版本: v1.21.3

## 安装方法 (在 Termux 中)

```bash
echo 'deb [trusted=yes] https://raw.githubusercontent.com/masgzy/reasonix-termux/apt stable main' \
  > $PREFIX/etc/apt/sources.list.d/reasonix.list
pkg update
pkg install reasonix
reasonix --version
```

## 分支内容

这是一个 orphan 分支 (单 commit, 每次发布重置历史),
只包含 apt 源文件 + 一个主页 index.html:

```
index.html                                       # 项目主页 (GitHub Pages / Cloudflare Pages 用)
dists/stable/Release                             # apt 元数据
dists/stable/main/binary-aarch64/Packages        # 包索引
dists/stable/main/binary-aarch64/Packages.gz     # 包索引 (gzip)
dists/stable/main/binary-aarch64/reasonix_<version>_aarch64.deb
```

源 workflow 在 main 分支上。
