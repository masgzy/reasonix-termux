#!/usr/bin/env bash
# ============================================================================
# Reasonix Termux 一键安装脚本
# ----------------------------------------------------------------------------
# 配色: Catppuccin Mocha (swk 颜色方案 shell 实现)
#   - 自动检测 NO_COLOR / 非 TTY 时降级为无色
#   - 符号前缀色盲友好: [OK] [X] [!] [i] -> *
#   - 中文友好: 黄色仅用于数字, 避免纯青/纯黄前景
# ============================================================================
#
# 用法:
#   方式 1 (推荐): 下载后编辑再运行
#     curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh -o install-reasonix.sh
#     nano install-reasonix.sh   # 修改 OWNER_REPO 和 MIRRORS
#     bash install-reasonix.sh
#
#   方式 2 (一行命令, 默认配置):
#     curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh | bash
#
# ============================================================================

set -e

# ===== 配置区 (用户自行修改) =====
OWNER_REPO="your-username/your-repo"  # ← 替换为你的实际仓库
APT_BRANCH="apt"                       # 发布分支
APT_DIST="stable"                      # apt distribution
APT_COMPONENT="main"                   # apt component

# 镜像列表 - 自行增删
# 格式: "名称|URL前缀"
# 含 "your-username" / "your-project" / "your-repo" 的占位 URL 会被自动跳过
MIRRORS=(
  "GitHub Raw|https://raw.githubusercontent.com/${OWNER_REPO}/${APT_BRANCH}"
  "GitHub /raw/ URL|https://github.com/${OWNER_REPO}/raw/${APT_BRANCH}"
  "GitHub Pages|https://your-username.github.io/your-repo"
  "Cloudflare Pages|https://your-project.pages.dev"
  "jsDelivr CDN|https://cdn.jsdelivr.net/gh/${OWNER_REPO}@${APT_BRANCH}"
)
# ===== 配置区结束 =====

# ---------------------------------------------------------------------------
# swk 颜色方案 (Catppuccin Mocha - shell 轻量实现)
# ---------------------------------------------------------------------------
# 检测: NO_COLOR 环境变量 / 非 TTY / TERM=dumb -> 无色模式
if [ -n "$NO_COLOR" ] || ! [ -t 1 ] || [ "$TERM" = "dumb" ]; then
  C_RESET=""
  C_TITLE=""
  C_DIM=""
  C_SUCCESS=""
  C_WARN=""
  C_ERROR=""
  C_INFO=""
  C_PATH=""
  C_NUMBER=""
  C_KEYWORD=""
else
  C_RESET="\033[0m"
  # Catppuccin Mocha - 24-bit true color (现代终端均支持)
  C_TITLE="\033[1;38;2;203;166;247m"    # Mauve  加粗 - 标题
  C_DIM="\033[2;38;2;166;173;200m"      # Subtext 暗淡 - 次要信息
  C_SUCCESS="\033[1;38;2;166;227;161m"  # Green  加粗 - 成功
  C_WARN="\033[1;38;2;250;179;135m"     # Peach  加粗 - 警告
  C_ERROR="\033[1;38;2;243;139;168m"    # Red    加粗 - 错误
  C_INFO="\033[38;2;137;220;235m"       # Sky          - 信息
  C_PATH="\033[38;2;137;180;250m"       # Blue         - 路径/URL
  C_NUMBER="\033[38;2;249;226;175m"     # Yellow       - 数字
  C_KEYWORD="\033[1;38;2;245;194;231m"  # Pink   加粗 - 关键字/编号
fi

# 符号前缀 (色盲友好 - 用 ASCII 替代 Unicode 符号)
SYM_OK="[OK]"
SYM_FAIL="[X]"
SYM_WARN="[!]"
SYM_INFO="[i]"
SYM_ARROW="->"

# ---------------------------------------------------------------------------
# 输出辅助函数
# ---------------------------------------------------------------------------
log_title()   { echo -e "${C_TITLE}${SYM_ARROW} $*${C_RESET}"; }
log_ok()      { echo -e "${C_SUCCESS}${SYM_OK} $*${C_RESET}"; }
log_warn()    { echo -e "${C_WARN}${SYM_WARN} $*${C_RESET}"; }
log_error()   { echo -e "${C_ERROR}${SYM_FAIL} $*${C_RESET}" >&2; }
log_info()    { echo -e "${C_INFO}${SYM_INFO} $*${C_RESET}"; }
log_dim()     { echo -e "${C_DIM}$*${C_RESET}"; }
log_path()    { echo -e "${C_PATH}$*${C_RESET}"; }
log_num()     { echo -e "${C_NUMBER}$*${C_RESET}"; }
log_keyword() { echo -e "${C_KEYWORD}$*${C_RESET}"; }

# 简易表格打印 (printf 对齐, 不用复杂边框)
# 用法: print_table "标题1|标题2" "行1列1|行1列2" "行2列1|行2列2" ...
print_table() {
  local header="$1"
  shift

  # 计算每列最大宽度
  declare -a col_widths
  # 先看表头
  IFS='|' read -ra headers <<< "$header"
  for i in "${!headers[@]}"; do
    col_widths[$i]=${#headers[$i]}
  done
  # 再看每行
  local rows=("$@")
  for row in "${rows[@]}"; do
    IFS='|' read -ra cells <<< "$row"
    for i in "${!cells[@]}"; do
      if [ ${#cells[$i]} -gt ${col_widths[$i]:-0} ]; then
        col_widths[$i]=${#cells[$i]}
      fi
    done
  done

  # 打印表头 (紫色加粗)
  local header_line=""
  for i in "${!headers[@]}"; do
    local w=${col_widths[$i]}
    header_line+=$(printf "${C_TITLE}%-${w}s${C_RESET}" "${headers[$i]}")
    [ $i -lt $((${#headers[@]} - 1)) ] && header_line+="  "
  done
  echo "  $header_line"

  # 分隔线
  local sep=""
  for i in "${!headers[@]}"; do
    local w=${col_widths[$i]}
    sep+=$(printf "%-${w}s" "" | tr ' ' '-')
    [ $i -lt $((${#headers[@]} - 1)) ] && sep+="  "
  done
  echo "  ${C_DIM}${sep}${C_RESET}"

  # 打印数据行
  for row in "${rows[@]}"; do
    IFS='|' read -ra cells <<< "$row"
    local line=""
    for i in "${!cells[@]}"; do
      local w=${col_widths[$i]}
      local cell="${cells[$i]}"
      # 数字开头(含 ms / KB / MB / 不可达)用黄色
      if [[ "$cell" =~ ^[0-9]+ ]] || [[ "$cell" == "不可达" ]]; then
        line+=$(printf "${C_NUMBER}%-${w}s${C_RESET}" "$cell")
      elif [[ "$cell" == "占位" || "$cell" == "(跳过)" ]]; then
        line+=$(printf "${C_DIM}%-${w}s${C_RESET}" "$cell")
      else
        line+=$(printf "%-${w}s" "$cell")
      fi
      [ $i -lt $((${#cells[@]} - 1)) ] && line+="  "
    done
    echo "  $line"
  done
}

# ---------------------------------------------------------------------------
# 前置检查
# ---------------------------------------------------------------------------
echo -e "${C_TITLE}╭──────────────────────────────────────────╮${C_RESET}"
echo -e "${C_TITLE}│  Reasonix Termux 一键安装脚本            │${C_RESET}"
echo -e "${C_TITLE}╰──────────────────────────────────────────╯${C_RESET}"
echo ""

if [ -z "$PREFIX" ] || [ ! -d "/data/data/com.termux" ]; then
  log_error "此脚本必须在 Termux 环境中运行"
  exit 1
fi

if [ "$OWNER_REPO" = "your-username/your-repo" ]; then
  log_error "请先编辑脚本, 把 OWNER_REPO 改为实际仓库"
  echo ""
  log_dim "下载并编辑后再运行:"
  echo "  curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh -o install-reasonix.sh"
  echo "  nano install-reasonix.sh"
  echo "  bash install-reasonix.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: 询问是否切换清华源
# ---------------------------------------------------------------------------
echo -e "${C_TITLE}[1/5] Termux 官方源${C_RESET}"
log_dim "  清华源 (tuna) 通常比默认源快很多 (国内尤其明显)"
read -p "  是否切换到清华源? [Y/n] " switch_tsinghua
switch_tsinghua=${switch_tsinghua:-Y}

if [[ "$switch_tsinghua" =~ ^[Yy]$ ]]; then
  log_info "切换中..."
  sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' "$PREFIX/etc/apt/sources.list"
  apt update
  log_ok "清华源切换完成"
else
  log_info "保持默认源, 执行 pkg update..."
  pkg update
fi

# ---------------------------------------------------------------------------
# Step 2: 检查 curl
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_TITLE}[2/5] 检查 curl${C_RESET}"
if command -v curl &>/dev/null; then
  log_ok "curl 已安装 $(log_dim "($(curl --version | head -1))")"
else
  log_warn "curl 未安装, 正在安装 $(log_keyword "(pkg install -y curl)")..."
  pkg install -y curl
  if ! command -v curl &>/dev/null; then
    log_error "curl 安装失败, 请手动运行: pkg install curl"
    exit 1
  fi
  log_ok "curl 安装完成"
fi

# ---------------------------------------------------------------------------
# Step 3: 测试镜像延迟
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_TITLE}[3/5] 测试镜像延迟${C_RESET}"
log_dim "  正在测试每个镜像的 $(log_path "dists/${APT_DIST}/Release") 文件..."
echo ""

RELEASE_PATH="dists/${APT_DIST}/Release"

# 数组: 每个镜像的延迟 (ms), -1 = 不可达, -2 = 占位跳过
declare -a LATENCIES
best_idx=-1
best_latency=999999
valid_count=0

# 先收集结果, 然后用 print_table 输出
table_rows=()

for i in "${!MIRRORS[@]}"; do
  IFS='|' read -r name url <<< "${MIRRORS[$i]}"

  # 跳过占位 URL
  if [[ "$url" == *"your-username"* ]] || \
     [[ "$url" == *"your-project"* ]] || \
     [[ "$url" == *"your-repo"* ]]; then
    LATENCIES[$i]=-2
    table_rows+=("$(log_keyword "$((i+1))")|$name|$(log_dim "(跳过)")")
    continue
  fi

  full_url="${url}/${RELEASE_PATH}"

  # 测试 3 次取平均
  total_ms=0
  success=0
  for try in 1 2 3; do
    start=$(date +%s%N)
    if curl -sf -o /dev/null --max-time 5 "$full_url" 2>/dev/null; then
      end=$(date +%s%N)
      ms=$(( (end - start) / 1000000 ))
      total_ms=$((total_ms + ms))
      success=$((success + 1))
    fi
  done

  if [ $success -gt 0 ]; then
    avg_ms=$((total_ms / success))
    LATENCIES[$i]=$avg_ms
    valid_count=$((valid_count + 1))
    table_rows+=("$(log_keyword "$((i+1))")|$name|${avg_ms}ms")
    if [ $avg_ms -lt $best_latency ]; then
      best_latency=$avg_ms
      best_idx=$i
    fi
  else
    LATENCIES[$i]=-1
    table_rows+=("$(log_keyword "$((i+1))")|$name|不可达")
  fi
done

# 输出表格
print_table "序号|镜像名称|延迟" "${table_rows[@]}"

if [ $valid_count -eq 0 ]; then
  echo ""
  log_error "所有镜像都不可达, 请检查:"
  echo "  $(log_dim '1.') 网络连接"
  echo "  $(log_dim '2.') OWNER_REPO 是否正确: $(log_path "$OWNER_REPO")"
  echo "  $(log_dim '3.') apt 分支是否已发布 (查看仓库的 apt 分支)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 4: 让用户选择镜像
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_TITLE}[4/5] 选择镜像${C_RESET}"
if [ $best_idx -ge 0 ]; then
  IFS='|' read -r best_name _ <<< "${MIRRORS[$best_idx]}"
  log_info "直接回车 = 选择延迟最低的镜像:"
  echo "    $(log_keyword "[$((best_idx+1))]") $(log_path "$best_name") $(log_num "(${best_latency}ms)")"
fi
read -p "  请输入序号 (1-${#MIRRORS[@]}), 或直接回车使用推荐: " choice

if [ -z "$choice" ]; then
  if [ $best_idx -lt 0 ]; then
    log_error "没有可用的镜像, 退出"
    exit 1
  fi
  selected=$best_idx
  log_ok "已选择: $(log_path "${MIRRORS[$selected]%%|*}")"
else
  # 验证输入
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    log_error "无效输入, 退出"
    exit 1
  fi
  selected=$((choice - 1))
  if [ $selected -lt 0 ] || [ $selected -ge ${#MIRRORS[@]} ]; then
    log_error "序号超出范围, 退出"
    exit 1
  fi
  if [ "${LATENCIES[$selected]:-0}" = "-1" ]; then
    log_error "该镜像不可达, 退出"
    exit 1
  elif [ "${LATENCIES[$selected]:-0}" = "-2" ]; then
    log_error "该镜像是占位 URL, 请先在脚本中配置"
    exit 1
  fi
  log_ok "已选择: $(log_path "${MIRRORS[$selected]%%|*}")"
fi

IFS='|' read -r selected_name selected_url <<< "${MIRRORS[$selected]}"
source_line="deb [trusted=yes] ${selected_url} ${APT_DIST} ${APT_COMPONENT}"

# ---------------------------------------------------------------------------
# Step 5: 写入源 + 安装
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_TITLE}[5/5] 写入源并安装${C_RESET}"
log_info "将写入: $(log_path "$PREFIX/etc/apt/sources.list.d/reasonix.list")"
log_info "源行:   $(log_keyword "$source_line")"
echo ""

echo "$source_line" > "$PREFIX/etc/apt/sources.list.d/reasonix.list"

log_info "执行 pkg update..."
pkg update

echo ""
log_info "执行 pkg install -y reasonix..."
pkg install -y reasonix

# ---------------------------------------------------------------------------
# 验证安装
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_SUCCESS}╭──────────────────────────────────────────╮${C_RESET}"
echo -e "${C_SUCCESS}│  安装完成                                │${C_RESET}"
echo -e "${C_SUCCESS}╰──────────────────────────────────────────╯${C_RESET}"
echo ""

if command -v reasonix &>/dev/null; then
  log_ok "reasonix 已安装到: $(log_path "$(command -v reasonix)")"
  echo ""
  echo -e "${C_TITLE}版本信息:${C_RESET}"
  reasonix --version 2>/dev/null || log_dim "  (运行 reasonix --help 查看帮助)"
else
  log_warn "reasonix 命令未找到, 安装可能失败"
  echo "  请检查上面的输出, 或手动运行: $(log_keyword "pkg install reasonix")"
fi

echo ""
echo -e "${C_TITLE}后续更新${C_RESET} $(log_dim "(reasonix 上游发布新版后, 本仓库会自动同步)"):"
echo -e "  $(log_ok 'pkg update && pkg upgrade')"

echo ""
echo -e "${C_TITLE}只升级 reasonix:${C_RESET}"
echo -e "  $(log_ok 'pkg upgrade reasonix')"

echo ""
echo -e "${C_TITLE}查看可用版本:${C_RESET}"
echo -e "  $(log_info 'apt list --all-versions reasonix')"
