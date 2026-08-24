# npm 自动发布设置教程

本教程教你完成 `reasonix-termux` npm 包自动发布的**一次性手动配置**。

workflow 本身（`.github/workflows/sync-and-publish.yml`）已经写好，剩下唯一的待办就是把"认证"那一步打通。GitHub Actions 跑在云端，要替你向 npm 提交包，必须有"代表你"的凭证。

---

## 前置条件（已完成的不用再做）

- ✅ npm 包 `reasonix-termux` 已在 npmjs.com 注册（你已做完，当前占位版本 `0.0.0`）
- ✅ GitHub 仓库 `masgzy/reasonix-termux` 已含 workflow `sync-and-publish.yml`（已写好）
- ✅ `aplaybox` 是协作者，有 write 权限（你已做完）
- ✅ workflow 已加 `id-token: write` 权限（已在 `publish_npm` job 配置）

剩下要做的：**选一种认证模式，给 workflow 一个能向 npm 提交的身份**。

---

## 两种认证模式对比

| 维度 | 模式 A: NPM_TOKEN secret | 模式 B: OIDC Trusted Publishing |
|------|--------------------------|--------------------------------|
| 安全性 | 中（token 泄露需手动吊销） | 高（无长期 token，每次发布换短期 OIDC token） |
| 配置难度 | 低（5 分钟） | 中（10 分钟，要改 workflow 几行） |
| token 管理 | 需手动轮换（建议 90 天） | 无需管理 |
| provenance | 支持（`--provenance`） | 自动生成 |
| 社区推荐度 | 兼容老项目 | **2026 主流推荐** |

> **建议**：第一次跑通用模式 A，跑通后再切到模式 B（更安全）。两种模式 workflow 已同时支持，切换只需改 2 行。

---

## 模式 A：NPM_TOKEN secret（默认，5 分钟搞定）

workflow 当前默认按此模式运行。你只要做两件事：

### 1. 在 npmjs.com 创建 Access Token

1. 用注册 `reasonix-termux` 的 npm 账号登录 <https://www.npmjs.com>
   - 你说过这包是 `krypmc` 注册的，那就用 `krypmc` 登录（不是 aplaybox）
2. 右上角头像 → **Access Tokens** → **Generate New Token**
3. 类型选 **Automation**（专门给 CI 用，不会被 2FA 拦）
   - 或选 **Granular Access Token**（更细粒度）：包选 `reasonix-termux`，权限勾 `Read and write`，过期 90 天
4. 复制 token（形如 `npm_abcDEF...`，**只显示一次**）

### 2. 把 token 加到 GitHub repo secret

**方式 1（推荐，UI）**：
1. 打开 <https://github.com/masgzy/reasonix-termux/settings/secrets/actions>
2. 点 **New repository secret**
3. Name: `NPM_TOKEN`（必须叫这个名字，对齐 workflow 里的 `secrets.NPM_TOKEN`）
4. Secret: 粘贴上面那个 token
5. 点 **Add secret**

**方式 2（CLI，token 还没吊销时可用）**：

```bash
# 用 GitHub API 加 secret (需要 GitHub PAT + 公钥加密)
# 这里直接用 gh CLI (推荐)
gh secret set NPM_TOKEN \
  --repo masgzy/reasonix-termux \
  --body "npm_xxxxxxxxxxxxx"
```

> `gh` 命令在 macOS `brew install gh`、Linux `apt install gh`、Termux `pkg install gh`。

---

## 模式 B：OIDC Trusted Publishing（更安全，10 分钟）

把 NPM_TOKEN 完全干掉，改用 GitHub OIDC 直接换 npm 短期 token。**前提**：你得是 npm 包的 owner 才能配 trusted publisher。

### 1. 编辑 workflow（删 2 行）

打开 `.github/workflows/sync-and-publish.yml`，找到 `publish_npm` job：

**改动 1** — 删 setup-node 步骤的 `registry-url`（避免 .npmrc 写空 token 占位）：

```yaml
# 改前
      - name: Setup Node.js (配置 npm 认证)
        if: steps.check_published.outputs.already_published != 'true'
        uses: actions/setup-node@v7
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org/'   ← 删这行
```

```yaml
# 改后
      - name: Setup Node.js
        if: steps.check_published.outputs.already_published != 'true'
        uses: actions/setup-node@v7
        with:
          node-version: '20'
```

**改动 2** — 删发布步骤的 `env`：

```yaml
# 改前
      - name: 发布到 npm (--provenance)
        if: steps.check_published.outputs.already_published != 'true'
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}    ← 删这整段 env
        run: |
          cd staging
          npm publish --access public --provenance
```

```yaml
# 改后
      - name: 发布到 npm (--provenance)
        if: steps.check_published.outputs.already_published != 'true'
        run: |
          cd staging
          npm publish --access public --provenance
```

`id-token: write` 权限**保留不动**（OIDC 必需）。

### 2. 在 npmjs.com 配置 Trusted Publisher

1. 用 `krypmc` 账号登录 <https://www.npmjs.com>
2. 进 <https://www.npmjs.com/package/reasonix-termux/access> → **Publishing access**
3. 选 **Configure GitHub Actions trusted publishing**
4. 填表：
   - **Repository owner**: `masgzy`
   - **Repository name**: `reasonix-termux`
   - **Workflow filename**: `sync-and-publish.yml`（不带 `.github/workflows/` 前缀）
   - **Environment**: 留空（不限制）
5. 保存

完成后这个包就只接受来自 `masgzy/reasonix-termux` 仓库 + `sync-and-publish.yml` workflow 的 OIDC 请求。别人拿不到你的 npm token 也无法冒充发布。

---

## 验证（两种模式都适用）

### 1. 手动触发一次 workflow

1. 进 <https://github.com/masgzy/reasonix-termux/actions/workflows/sync-and-publish.yml>
2. 右上角 **Run workflow** ▼
3. Branch: `main`，Force: `true`（强制重跑，即使上游没新版本）
4. 点 **Run workflow**

### 2. 观察运行

正常跑约 5 分钟，分四个 job：

```
detect        ✓  (检测上游版本, 当前 v1.31.3)
build         ✓  (Go 交叉编译 → reasonix 二进制)
publish       ✓  (apt orphan 分支 force-push)
publish_npm   ✓  (npm publish reasonix-termux@1.31.3)
```

进 `publish_npm` job 看详细日志，最后应该出现：

```
✓ 已发布 reasonix-termux@1.31.3
  https://www.npmjs.com/package/reasonix-termux/v/1.31.3
```

### 3. 访问 npm 页面确认

打开 <https://www.npmjs.com/package/reasonix-termux>，应该看到：

- 版本从 `0.0.0` 变成 `1.31.3`（与上游 tag 一致）
- README 出现（npm/README.md 的内容）
- 包大小约 11 MB（android/arm64 静态 ELF）
- 有 **Provenance** 标签（绿色 ✓，表示供应链证明已生成）

### 4. 在 Termux 实测

```bash
# 任意 Android 手机 Termux
pkg install nodejs
npm install -g reasonix-termux
reasonix --version
# 输出应为: 1.31.3 (或当时最新版)
```

---

## 版本同步机制（自动化部分）

workflow 已经实现"版本号实时同步"：

1. `detect` job 调 GitHub API 查上游 `esengine/DeepSeek-Reasonix` 最新 stable release tag（如 `v1.31.3`）
2. `build` job 用此 tag 检出上游源码并构建
3. `publish_npm` job 拿到 `UPSTREAM_TAG=v1.31.3`，执行：
   ```bash
   VER="${UPSTREAM_TAG#v}"   # 去掉 v 前缀 → 1.31.3
   npm version "$VER" --no-git-tag-version
   ```
   写进 `package.json` 后 `npm publish`
4. 发布前先查 `https://registry.npmjs.org/reasonix-termux/1.31.3`，已存在则跳过（幂等，可重跑）

**触发频率**：workflow 默认每 6 小时跑一次（UTC 00:30/06:30/12:30/18:30）。上游出新 release 后，最长 6 小时内 npm 上自动同步。

---

## 故障排查

### `ENEEDAUTH` - npm publish 报认证失败

| 模式 | 原因 | 修法 |
|------|------|------|
| A | `NPM_TOKEN` secret 没设 / 值错 / 已过期 | 重新生成 token，更新 secret |
| A | token 类型选错（选了 "Read-only"） | 重建 token，选 **Automation** 或 granular 带 publish |
| A | npm 账号不是包 owner | 用注册该包的账号（`krypmc`）生成 token |
| B | workflow 没删 `NODE_AUTH_TOKEN` env 行 | 按模式 B 第 1 步删掉 |
| B | npm 上 trusted publisher 没配好 | 检查 Repository owner/name/Workflow filename 是否完全匹配 |
| B | `id-token: write` 权限丢失 | 检查 `publish_npm` job 的 `permissions` 字段 |

### `E403 - You cannot publish over an existing version`

此版本已发布过。workflow 已加 `check_published` 步骤自动跳过，正常不会出现。若手动跑出此错，说明 check 步骤漏跑了（npm registry 同步延迟，刚发布的版本还没出现在 GET 接口），等 1 分钟再跑。

### `EBADPLATFORM` - 在非 Termux 装

预期行为。`package.json` 限定 `os: ["android"], cpu: ["arm64"]`，npm 在 macOS/Linux/Windows 上会主动拒装。Termux 里 Node.js 报告 `process.platform === 'android'`，所以能装。

如果 Termux 里也报 EBADPLATFORM：检查 Node.js 版本，`process.platform` 在 Node 16+ 才稳定报 `android`。`pkg install nodejs` 装的版本一般够新。

### workflow 不触发

- 检查 `.github/workflows/sync-and-publish.yml` 在 `main` 分支根目录下 `.github/workflows/` 子目录里
- 进 repo Settings → Actions → General，确认不是 "Disable Actions"
- public repo 默认就开，private repo 要手动开

### 二进制下载失败

`publish_npm` 依赖 `build` job 上传的 `reasonix-binary` artifact。如果 build job 失败，artifact 不会上传，publish_npm 会卡在 "下载 reasonix 二进制" 步骤。先看 build job 日志。

---

## Provenance 验证（可选）

发布后可以验证 npm 包带 provenance 标签：

```bash
# 查包元数据
npm view reasonix-termux@1.31.3 dist.integrity dist.tarball

# 查 provenance attestation
npm audit signatures

# 或用 sigstore 工具链验证 (更严格)
npm install -g @sigstore/cli
sigstore verify reasonix-termux@1.31.3
```

Provenance attestation 里会包含：仓库 URL、commit SHA、workflow 路径、运行 runner 信息。可证明"这个 npm 包确实是 masgzy/reasonix-termux 的 main 分支在某个 commit 跑 workflow 时发布的"。

---

## 相关文档

- [GitHub 官方: Publishing Node.js packages](https://docs.github.com/actions/publishing-packages/publishing-nodejs-packages)
- [npm 官方: Trusted publishing for npm packages](https://docs.npmjs.com/trusted-publishers)
- [npm 官方: Generating provenance statements](https://docs.npmjs.com/generating-provenance-statements)
- [npm 包主页: reasonix-termux](https://www.npmjs.com/package/reasonix-termux)
- [本仓库 workflow: sync-and-publish.yml](../.github/workflows/sync-and-publish.yml)
