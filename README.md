# Reasonix Termux APT Repository

自动同步 [esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix) 上游 CLI 版本，构建 **Android / aarch64** 静态二进制，并通过 **orphan 分支** 提供 Termux 兼容的 apt 源。

## 一、快速开始（一键脚本）

在 Termux 中运行：

```bash
# 方式 1: 一行命令 (使用默认镜像配置, 共五个镜像源)
curl -fsSL https://raw.githubusercontent.com/masgzy/Reasonix-termux/main/scripts/install.sh | bash

# 方式 2: 下载后编辑镜像列表再运行 (推荐)
curl -fsSL https://raw.githubusercontent.com/masgzy/Reasonix-termux/main/scripts/install.sh -o install-reasonix.sh
nano install-reasonix.sh   # 修改 OWNER_REPO 和 MIRRORS 列表
bash install-reasonix.sh
```

脚本会自动完成：
1. 询问是否切换清华源（加速 Termux 官方源）
2. 检测 `curl` 是否存在，缺失则 `pkg install -y curl`
3. 测试各镜像的 `dists/stable/Release` 延迟（3 次取平均）
4. 让你选择镜像，**直接回车 = 选择延迟最低的**（会显示推荐序号）
5. 写入源到 `$PREFIX/etc/apt/sources.list.d/reasonix.list`
6. `pkg update && pkg install -y reasonix`

## 二、手动安装

如果你想完全手动控制：

```bash
# 1. 选一个镜像 (见下方"镜像列表")
MIRROR="https://raw.githubusercontent.com/masgzy/Reasonix-termux/apt"

# 2. 写入源
echo "deb [trusted=yes] ${MIRROR} stable main" \
  > $PREFIX/etc/apt/sources.list.d/reasonix.list

# 3. 更新并安装
pkg update
pkg install reasonix

# 4. 验证
reasonix --version
```

## 三、镜像列表

所有镜像的 apt 源行格式都是 `deb [trusted=yes] <MIRROR> stable main`，把 `<MIRROR>` 替换为下表中任一 URL 前缀即可。

| 镜像                | URL 前缀                                                            | 说明                                             |
|--------------------|---------------------------------------------------------------------|--------------------------------------------------|
| **GitHub Raw**     | `https://raw.githubusercontent.com/masgzy/Reasonix-termux/apt`              | 默认，最稳定                                      |
| **GitHub /raw/**   | `https://github.com/masgzy/Reasonix-termux/raw/apt`                         | 同上，走 github.com 域名（同 IP，不同 host）     |
| **GitHub Pages**   | `https://rx.996855.xyz/apt`                                  | 需在仓库 Settings → Pages 启用，源 = `apt` 分支  |
| **Cloudflare Pages** | `https://rxc.996855.xyz/`                                     | 需在 Cloudflare Pages 接入仓库，生产分支 = `apt` |
| **jsDelivr CDN**   | `https://cdn.jsdelivr.net/gh/masgzy/Reasonix-termux@apt`                    | 海外 CDN，国内有时被墙                            |

**Orphan 分支方案**（类似 GitHub Pages 的 `gh-pages` 分支）：
- 创建一个独立的 `apt` 分支
- 该分支只包含 apt 源文件（无 workflow、无源码）
- 文件路径完全保留目录结构
- 每次发布用 `git push --force` 覆盖，分支永远只有 1 个 commit，体积恒等于当前 deb 大小

## 五、源结构

`apt` 分支上的文件：

```
apt 分支根目录/
├── README.md                                           # 自动生成的访问者说明
└── dists/
    └── stable/
        ├── Release                                     # apt 元数据 (Architectures/Components/Checksums)
        └── main/
            └── binary-aarch64/
                ├── Packages                            # 包索引（文本）
                ├── Packages.gz                         # 包索引（gzip）
                └── reasonix_<version>_aarch64.deb      # 实际安装包
```

URL 映射（以 GitHub Raw 为例，base = `https://raw.githubusercontent.com/masgzy/Reasonix-termux/apt`）：

| 文件                | 完整 URL                                                                        |
|--------------------|---------------------------------------------------------------------------------|
| `Release`          | `.../apt/dists/stable/Release`                                                  |
| `Packages`         | `.../apt/dists/stable/main/binary-aarch64/Packages`                             |
| `Packages.gz`      | `.../apt/dists/stable/main/binary-aarch64/Packages.gz`                          |
| `*.deb`            | `.../apt/dists/stable/main/binary-aarch64/reasonix_<ver>_aarch64.deb`           |

用户 apt 拉取流程：
1. `pkg update` → 拉取 `<base>/dists/stable/Release` 读架构/组件
2. 拉取 `<base>/dists/stable/main/binary-aarch64/Packages.gz` 解析可用包
3. 从 `Packages` 中读到的 `Filename` 字段（相对路径）拼接 base 拉取 .deb
4. `dpkg -i` 安装到 `/data/data/com.termux/files/usr/bin/reasonix`

## 六、后续更新（重要）

安装完成后，**不需要重跑一键脚本**。本仓库每 6 小时自动检测上游 Reasonix 发布的新版本并自动推送到 `apt` 分支。

你只需要定期执行：

```bash
# 升级所有已安装的包 (包括 reasonix)
pkg update && pkg upgrade

# 或者只升级 reasonix
pkg upgrade reasonix

# 查看可用版本
apt list --all-versions reasonix
```

`pkg update` 会从镜像重新拉取 `Packages.gz`，发现新版本后 `pkg upgrade` 会自动下载安装。

## 七、deb 大小实测（v1.19.7 真实构建）

在本地用 Go 1.26.5 真实 checkout 上游 `v1.19.7` tag 并构建：

| 文件                                  | 大小         |
|--------------------------------------|--------------|
| `reasonix` 裸二进制 (GOOS=android)    | 32.44 MB     |
| `reasonix_1.19.7_aarch64.deb`        | **11.19 MB** |
| `Packages` 索引                       | 735 B        |
| `Packages.gz`                        | 511 B        |
| `Release`                            | 526 B        |

deb 内部用 gzip 压缩 `data.tar.gz`，最终大小比裸二进制还小 65%（Go 二进制可压缩性高）。

### 各项限制对照

| 限制                                  | 阈值        | 实际占用   | 状态     |
|--------------------------------------|-------------|------------|----------|
| Cloudflare Pages 单文件              | 25 MB       | 11.19 MB   | ✅ PASS  |
| GitHub 警告阈值（>50 MB）            | 50 MB       | 11.19 MB   | ✅ PASS  |
| GitHub push 禁止阈值（>100 MB）      | 100 MB      | 11.19 MB   | ✅ PASS  |
| GitHub Release 单 asset 上限         | 2 GB        | 11.19 MB   | ✅ PASS  |
| raw.githubusercontent.com 单文件     | 100 MB      | 11.19 MB   | ✅ PASS  |
| jsDelivr 单文件                      | 50 MB       | 11.19 MB   | ✅ PASS  |

> 即使未来上游 Reasonix 二进制翻倍到 ~65 MB，deb 压缩后约 22 MB，**仍在 Cloudflare Pages 25 MB 限制内**。

## 八、构建参数

| 项目            | 值                          | 说明                                                       |
|-----------------|----------------------------|------------------------------------------------------------|
| `GOOS`          | `android`                  | 用户指定                                                   |
| `GOARCH`        | `arm64`                    | 对应 aarch64                                               |
| `CGO_ENABLED`   | `0`                        | 纯静态 ELF，bionic libc 上可直接运行                       |
| LDFLAGS         | `-s -w -X main.version=...`| 与上游 Reasonix goreleaser 一致                            |
| Binary path     | `./cmd/reasonix`           | 上游 main package                                          |
| Deb arch        | `aarch64`                  | **Termux apt 源用 `aarch64` 而非 `arm64`**                 |
| Deb install dir | `/data/data/com.termux/files/usr/bin/` | Termux 标准前缀                                |

> ⚠️ **关于 `GOOS=android`**：Go 工具链支持 `GOOS=android + CGO_ENABLED=0`，产物为 ARM aarch64 ELF（`interpreter /system/bin/linker64`，但实际不链接 libc），在 Termux 上能直接运行。若未来 Go 拒绝该组合，workflow 已内置回退到 `GOOS=linux GOARCH=arm64 CGO_ENABLED=0`（同样是静态 ELF，Termux 兼容）。

## 九、自动化机制

### 单一 workflow: `.github/workflows/sync-and-publish.yml`

**触发器**：
- `schedule`: 每 6 小时检查一次上游（cron `30 */6 * * *` UTC，对应北京时间 08:30 / 14:30 / 20:30 / 02:30）
- `workflow_dispatch`: 支持手动触发 + `force=true` 强制重建 + `tag=v1.x.x` 指定版本

**权限**（已在 workflow 中显式声明）：
```yaml
permissions:
  contents: write    # push 到 apt 分支 + commit version.txt
  actions: read
```

> 同时也需要在仓库 Settings → Actions → General → Workflow permissions 选 **Read and write permissions**。

**3 个 job**：

```
detect  →  build  →  publish (orphan branch force-push)
            ↓
       upload-artifact (apt-root/)
```

| Job        | 职责                                                                       |
|------------|----------------------------------------------------------------------------|
| `detect`   | 调用 GitHub API 取上游 latest release tag，与本地 `version.txt` 比较       |
| `build`    | checkout 上游源码 → setup-go → `go build` → `build-deb.sh` → `build-apt-repo.sh` |
| `publish`  | 创建 fresh orphan git → 复制 apt-root → `git push --force` 到 `apt` 分支    |

### 版本检测原理

```bash
# 上游 latest tag (取 releases/latest, 自动跳过 prerelease)
UPSTREAM=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/esengine/DeepSeek-Reasonix/releases/latest" \
  | jq -r '.tag_name')

# 本地已发布版本 (main 分支根目录的 version.txt)
CURRENT=$(cat version.txt)

# 决策
[ "$UPSTREAM" != "$CURRENT" ] && publish=true
```

`version.txt` 在 `main` 分支根目录，每次发布后由 bot 自动 commit，下次 workflow 检测时用作对比基准。**发布历史通过 main 分支的 version.txt commit log 保留**。

### Orphan 分支推送逻辑

```bash
# 每次 publish 都创建 fresh orphan (无父 commit)
mkdir apt-branch && cd apt-branch
git init -b apt
git remote add origin "https://github.com/$REPO.git"

# 复制新构建产物
cp -a ../apt-root/. .

# 单 commit 提交
git add -A
git commit -m "Publish reasonix $TAG"

# Force push 覆盖 - 分支永远只有 1 个 commit
git push origin apt --force
```

**优势**：
- 分支体积恒等于当前 deb 大小（~12 MB），不随版本累积
- 旧 commit 变成 unreachable，会被 GitHub 自动 GC 清理
- 即使发布 1000 次，仓库总占用仍然 ~12 MB

## 十、目录结构

```
reasonix-termux/                # main 分支
├── .github/
│   └── workflows/
│       └── sync-and-publish.yml     # 主 workflow
├── scripts/
│   ├── detect-upstream.sh           # 检测上游版本
│   ├── build-reasonix.sh            # 构建 Go 二进制
│   ├── build-deb.sh                 # 打包 .deb
│   ├── build-apt-repo.sh            # 生成 Packages/Release
│   └── install.sh                   # 用户侧一键安装脚本 ★ 新增
├── version.txt                      # 当前已发布版本号（自动更新）
├── README.md                        # 本文件
├── BUILD_REPORT.md                  # 实测构建报告
└── sample-artifacts/                # 真实构建样本（参考用）
    ├── reasonix_1.19.7_aarch64.deb
    ├── Release
    ├── Packages
    └── Packages.gz
```

`apt` 分支（orphan）只包含：

```
apt/
├── README.md                          # 自动生成
└── dists/stable/
    ├── Release
    └── main/binary-aarch64/
        ├── Packages
        ├── Packages.gz
        └── reasonix_<ver>_aarch64.deb
```

## 十一、自建步骤

1. **Fork / 新建仓库**：把 `reasonix-termux/` 目录所有文件提交到一个新的 GitHub 仓库（例如 `alice/reasonix-termux`）。

2. **检查 Actions 权限**：
   - 仓库 Settings → Actions → General → Workflow permissions → 选 **Read and write permissions**

3. **手动触发首次构建**：
   - 仓库 Actions 标签页 → 选 `Sync & Publish Termux Repo` → Run workflow → `force=true`

4. **等待构建完成**（约 3-5 分钟），然后查看 `apt` 分支：仓库 → 分支切换 → `apt`，应该能看到 `dists/stable/...` 目录结构。

5. **（可选）配置 GitHub Pages / Cloudflare Pages 镜像**：见上方"镜像列表"小节。

6. **在 Termux 中安装**：
   ```bash
   curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh | bash
   ```

## 十二、关于 `[trusted=yes]`

由于本仓库未对 `Release` 文件做 GPG 签名，用户必须在源行加上 `[trusted=yes]` 才能使用。

如果未来需要去掉这个标志（更安全），需要：
1. 生成 GPG key 并加到仓库 Secrets
2. 用 `gpg --detach-sign --armor` 对 Release 签名，产出 `InRelease` / `Release.gpg`
3. 在 workflow 中把签名文件也 push 到 `apt` 分支
4. 用户源行改为 `deb [signed-by=/path/to/key.gpg] https://... stable main`

## 十三、与上游 Reasonix 工作流的对比

| 方面                | 上游 Reasonix                          | 本仓库                          |
|---------------------|----------------------------------------|---------------------------------|
| 构建工具             | GoReleaser v2 + Makefile               | 直接 `go build`（更简单）       |
| 触发器               | `push: tags v*` + workflow_call        | `schedule` + `workflow_dispatch`|
| 二进制目标           | darwin/linux/windows × amd64/arm64     | android/arm64 (aarch64)         |
| 发布渠道             | GitHub Release (多版本 tag)            | orphan 分支 `apt` (单 commit)   |
| 包格式              | tar.gz / zip / .deb (desktop)          | .deb (Termux)                   |
| 自动更新检测         | 不需要（自己发布）                      | 每 6h cron 调 GitHub API         |
| 版本基准            | git tag                                | `version.txt` (commit by bot)   |
| URL 结构            | 平铺 `releases/download/v1.19.7/...`   | 层级 `raw/apt/dists/stable/...` |
