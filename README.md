# Reasonix Termux

在 Termux 里跑 [DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix) —— DeepSeek 原生的终端编码 agent。

自动同步上游 release，构建 Android/aarch64 静态二进制，通过 apt 源发布。装一次，后续 `pkg upgrade` 自动跟版。

考虑到大多数 harness 均使用 npm 发布二进制文件，目前已注册 npm 包，但尚未实现功能。

本项目部分文件使用了 Agent 进行编写，部分地方可能考虑不周，若有问题请提issue，描述你遇到了什么问题。

注: 本项目不是 reasonix 团队官方开发，且不存在隶属关系，仅patch修复tmp问题, 编译二进制文件并发布apt源。

---

## 安装

### 方式一：一键脚本（推荐）

任选下面三种写法之一，效果都一样：

**写法 1：`bash <(curl ...)`（推荐，stdin 是终端，交互最顺）**

```bash
bash <(curl -sL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh)
```

**写法 2：`bash <(wget ...)`（无 curl 环境用）**

```bash
bash <(wget -qO- -o- https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh)
```

**写法 3：`curl | bash`（兼容老式写法，脚本会自动从 `/dev/tty` 读输入）**

```bash
curl -fsSL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh | bash
```

脚本会引导你完成 5 步：

1. 询问是否切换清华源（国内用户建议切）
2. 检查 `curl`，缺失则自动 `pkg install -y curl`
3. 测五个镜像的延迟，每个测 3 次取平均
4. 选镜像（直接回车 = 选延迟最低的）
5. 写入源 + `pkg update` + `pkg install -y reasonix`

> 如果你想自定义镜像列表或仓库路径，先下载脚本再编辑：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh -o install.sh
> nano install.sh
> bash install.sh
> ```
>
> **非交互模式**（脚本/CI 场景，跳过所有询问，使用默认值：切清华源 + 选延迟最低的镜像）：
> ```bash
> REASONIX_NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh)"
> ```

### 方式二：手动安装

```bash
# 1. 选一个镜像 URL（见下方"镜像"章节）
MIRROR="https://raw.githubusercontent.com/masgzy/reasonix-termux/apt"

# 2. 写入 apt 源
echo "deb [trusted=yes] ${MIRROR} stable main" \
  > $PREFIX/etc/apt/sources.list.d/reasonix.list

# 3. 安装
pkg update
pkg install reasonix

# 4. 验证
reasonix --version
```

---

## 镜像

所有镜像指向同一份 apt 源，选延迟最低的就行。

| 镜像 | URL 前缀 |
|------|----------|
| GitHub Raw | `https://raw.githubusercontent.com/masgzy/reasonix-termux/apt` |
| GitHub Raw (美国代理) | `https://github.cnxiaobai.com/https://raw.githubusercontent.com/masgzy/reasonix-termux/apt` |
| GitHub Raw (CF优选代理) | `https://v6.gh-proxy.org/https://raw.githubusercontent.com/masgzy/reasonix-termux/apt` |
| GitHub Pages | `https://rxt.cc.cd/` |
| Cloudflare Pages | `https://cf.rxt.cc.cd/` |
| jsDelivr CDN | `https://cdn.jsdelivr.net/gh/masgzy/reasonix-termux@apt` |

源行格式（把 `<MIRROR>` 换成上表任一 URL）：

```
deb [trusted=yes] <MIRROR> stable main
```

---

## 更新

装好之后不用再跑安装脚本。本仓库每 6 小时检查上游新版本，自动构建并推送到 apt 分支。

```bash
# 升级所有包（含 reasonix）
pkg update && pkg upgrade

# 只升级 reasonix
pkg upgrade reasonix

# 查看可用版本
apt list --all-versions reasonix
```

---

## 卸载

```bash
pkg uninstall reasonix
rm $PREFIX/etc/apt/sources.list.d/reasonix.list
pkg update
```

---

## 常见问题

### `pkg install reasonix` 报 "Unable to locate package"

源没写进去或 `pkg update` 没执行。检查：

```bash
cat $PREFIX/etc/apt/sources.list.d/reasonix.list
```

应该有 `deb [trusted=yes] <MIRROR> stable main` 一行。如果没有，重跑安装脚本或手动写入。然后 `pkg update`。

### `pkg update` 报 `Release file is not valid yet` 或时间错误

Termux 时间不对。Android 上检查系统时间，必要时：

```bash
pkg install tsu
tsu -c "date -s 'YYYY-MM-DD HH:MM:SS'"
```

或直接在 Android 设置里开启自动时间。

### `reasonix` 命令找不到

确认 `/data/data/com.termux/files/usr/bin/reasonix` 存在：

```bash
ls -l $PREFIX/bin/reasonix
```

如果文件在但命令找不到，刷新 PATH：

```bash
hash -r
```

或重启 Termux。

### 装上后跑 `reasonix` 报 `Exec format error`

架构不匹配。本源目前只提供 `aarch64`（覆盖 99% 的现代 Android 手机）。查手机架构：

```bash
uname -m
```

- 如果输出 `aarch64`，说明装错了版本，重跑安装脚本即可。
- 如果输出 `armv7l` / `i686` / `x86_64`，当前暂未提供对应架构。**如果有需要，请到 [本仓库 issues](https://github.com/masgzy/reasonix-termux/issues) 提个 issue 说明架构和设备型号，会按需增加构建。**

需求多的话会加上多架构并行构建，需求少则保持现状（避免浪费 CI 时间）。

### 临时目录位置

Termux/Android 上 `/tmp` 只读，本仓库构建的 reasonix 已 patch 为使用 `~/.reasonix/tmp/` 作为临时目录。

正常情况无需手动配置。如果遇到 `permission denied` 或 `mkdir /tmp/...` 错误，检查：

```bash
# 确认临时目录可写
ls -ld ~/.reasonix/tmp/

# 如果不存在或权限不对，手动创建
mkdir -p ~/.reasonix/tmp
chmod 755 ~/.reasonix/tmp
```

也可以用环境变量覆盖：

```bash
export TMPDIR=~/.reasonix/tmp
reasonix
```

### `[trusted=yes]` 是什么意思

本源的 `Release` 文件未做 GPG 签名。`[trusted=yes]` 告诉 apt 显式信任这个源，跳过签名校验。如果不加，apt 会拒绝拉取。

### 怎么知道有新版本

```bash
apt list --upgradable reasonix
```

或者直接 `pkg update && pkg upgrade`。

### 切换镜像

改 `$PREFIX/etc/apt/sources.list.d/reasonix.list` 里的 URL，然后 `pkg update`。或重跑安装脚本选别的镜像。

---

## 上游与本仓库的关系

- **上游**：[esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix) — Reasonix CLI 官方仓库
- **本仓库**：仅做 Termux 分发。源码、二进制构建逻辑、商标、版权归上游所有
- 本仓库每 6 小时检查上游 release，发现新版本即自动构建 `GOOS=android GOARCH=arm64 CGO_ENABLED=0` 静态二进制，打包成 deb，推送到本仓库的 `apt` 分支
- 本仓库不对上游源码做任何修改，仅重新编译

如果遇到 Reasonix 本身的 bug（命令行参数、模型行为、prompt 处理等），请到上游提 issue：<https://github.com/esengine/DeepSeek-Reasonix/issues>

如果遇到安装/源/镜像/deb 打包问题，到本仓库提 issue：<https://github.com/masgzy/reasonix-termux/issues>

---

## 技术细节

### 构建参数

| 项 | 值 |
|----|----|
| GOOS | `android` |
| GOARCH | `arm64` |
| CGO_ENABLED | `0`（纯静态 ELF） |
| Deb 架构 | `aarch64`（Termux apt 用 `aarch64`，不是 `arm64`） |
| 安装路径 | `/data/data/com.termux/files/usr/bin/reasonix` |
| LDFLAGS | `-s -w -X main.version=<tag>` |

### apt 源结构

`apt` 分支上的文件：

```
dists/stable/Release                                  # apt 元数据
dists/stable/main/binary-aarch64/Packages             # 包索引
dists/stable/main/binary-aarch64/Packages.gz          # 包索引 (gzip)
dists/stable/main/binary-aarch64/reasonix_<ver>_aarch64.deb
```

### deb 大小

约 11 MB（具体随版本略有浮动）。远低于 GitHub push（100 MB）、raw.githubusercontent.com（100 MB）、jsDelivr（50 MB）、Cloudflare Pages（25 MB）所有限制。

### 发布机制

本仓库用 GitHub Actions 每 6 小时检查上游，自动构建并通过 orphan 分支发布。`apt` 分支永远只有 1 个 commit，体积恒等于当前 deb 大小，不会随版本累积。

发布历史通过 main 分支的 `version.txt` commit log 保留。

---

## License

本仓库的脚本、workflow、安装脚本、主页 HTML 以 **GPL-3.0** 协议发布。Reasonix 本身的 license 见上游仓库。

- 上游 [esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix) 的版权与 license 归上游所有
- 本仓库仅做 Termux 平台的分发与构建脚本，所有派生作品须遵循 GPL-3.0
- 完整协议文本见 [LICENSE](./LICENSE) 或 <https://www.gnu.org/licenses/gpl-3.0.html>
