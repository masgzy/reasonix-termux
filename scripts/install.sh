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
#   方式 1 (推荐): bash <(curl) - stdin 是终端, 交互最顺
#     bash <(curl -sL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh)
#
#   方式 2 (替代): bash <(wget) - 无 curl 环境用
#     bash <(wget -qO- -o- https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh)
#
#   方式 3 (兼容): curl | bash - 老式写法, 脚本会自动从 /dev/tty 读输入
#     curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh | bash
#
#   方式 4 (自定义): 下载后编辑再运行
#     curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/scripts/install.sh -o install-reasonix.sh
#     nano install-reasonix.sh   # 修改 OWNER_REPO 和 MIRRORS
#     bash install-reasonix.sh
#
#   方式 5 (非交互模式, 用于脚本/CI):
#     REASONIX_NONINTERACTIVE=1 bash install-reasonix.sh
#     # 全部使用默认值: 切清华源 + 选延迟最低的镜像
#
# 交互说明:
#   - 方式 1/2 (bash <(...)) 推荐: bash 的 stdin 是终端, read 直接能读输入
#   - 方式 3 (curl | bash): 脚本检测到 stdin 是管道后会改从 /dev/tty 读取输入
#   - 方式 5 (非交互): REASONIX_NONINTERACTIVE=1 跳过所有询问, 使用默认值
#
# ============================================================================

set -e

# ===== 配置区 (用户自行修改) =====
OWNER_REPO="masgzy/reasonix-termux"  # 仓库路径
APT_BRANCH="apt"                       # 发布分支
APT_DIST="stable"                      # apt distribution
APT_COMPONENT="main"                   # apt component

# 镜像列表 - 自行增删
# 格式: "名称|URL前缀"
MIRRORS=(
  "GitHub Raw|https://raw.githubusercontent.com/${OWNER_REPO}/${APT_BRANCH}"
  "GitHub Raw (美国代理)|https://github.cnxiaobai.com/https://raw.githubusercontent.com/${OWNER_REPO}/${APT_BRANCH}"
  "GitHub Raw (CF优选代理)|https://v6.gh-proxy.org/https://raw.githubusercontent.com/${OWNER_REPO}/${APT_BRANCH}"
  "GitHub Pages|https://rxt.cc.cd"
  "Cloudflare Pages|https://cf.rxt.cc.cd"
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
# 去除 ANSI 转义码, 返回纯文本 (用于计算可见宽度)
strip_ansi() {
  # 用 sed 去掉 ESC[...m 序列 (033 = ESC)
  printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'
}

print_table() {
  local header="$1"
  shift

  # 计算每列最大宽度 (基于可见字符, 去掉 ANSI 转义码)
  declare -a col_widths
  IFS='|' read -ra headers <<< "$header"
  for i in "${!headers[@]}"; do
    col_widths[$i]=$(strip_ansi "${headers[$i]}" | wc -m)
  done
  local rows=("$@")
  for row in "${rows[@]}"; do
    IFS='|' read -ra cells <<< "$row"
    for i in "${!cells[@]}"; do
      local cw=$(strip_ansi "${cells[$i]}" | wc -m)
      if [ "$cw" -gt "${col_widths[$i]:-0}" ]; then
        col_widths[$i]=$cw
      fi
    done
  done

  # 打印表头 (紫色加粗) - 用 printf %b 解释转义码
  local header_line=""
  for i in "${!headers[@]}"; do
    local w=${col_widths[$i]}
    local cell_visible=$(strip_ansi "${headers[$i]}" | wc -m)
    local pad=$(( w - cell_visible ))
    header_line+="${C_TITLE}${headers[$i]}$(printf '%*s' "$pad" '')${C_RESET}"
    [ $i -lt $((${#headers[@]} - 1)) ] && header_line+="  "
  done
  printf '  %b\n' "$header_line"

  # 分隔线 (暗淡)
  local sep=""
  for i in "${!headers[@]}"; do
    local w=${col_widths[$i]}
    sep+=$(printf '%-*s' "$w" '' | tr ' ' '-')
    [ $i -lt $((${#headers[@]} - 1)) ] && sep+="  "
  done
  printf '  %b%b%b\n' "$C_DIM" "$sep" "$C_RESET"

  # 打印数据行
  for row in "${rows[@]}"; do
    IFS='|' read -ra cells <<< "$row"
    local line=""
    for i in "${!cells[@]}"; do
      local w=${col_widths[$i]}
      local cell="${cells[$i]}"
      local cell_visible=$(strip_ansi "$cell" | wc -m)
      local pad=$(( w - cell_visible ))
      # cell 已经带颜色 (由调用方 log_xxx 函数加的), 直接用 + 右侧补空格
      line+="${cell}$(printf '%*s' "$pad" '')"
      [ $i -lt $((${#cells[@]} - 1)) ] && line+="  "
    done
    printf '  %b\n' "$line"
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

# 检查 OWNER_REPO 是否配置 (空值或占位符就报错)
# 注意: 默认值已经是 masgzy/reasonix-termux, fork 用户如果不改会装本仓库的源 (预期行为)
# 这里只拦截明显的占位符, 不拦截默认值
if [ -z "$OWNER_REPO" ] || \
   [[ "$OWNER_REPO" == *"your-username"* ]] || \
   [[ "$OWNER_REPO" == *"your-repo"* ]] || \
   [[ "$OWNER_REPO" == *"your-project"* ]]; then
  log_error "OWNER_REPO 未配置 ($OWNER_REPO)"
  echo ""
  log_dim "请下载脚本后编辑顶部的 OWNER_REPO 变量:"
  echo "  curl -fsSL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh -o install-reasonix.sh"
  echo "  nano install-reasonix.sh"
  echo "  bash install-reasonix.sh"
  exit 1
fi

# 校验 OWNER_REPO 格式 (必须是 owner/repo 形式)
if ! [[ "$OWNER_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  log_error "OWNER_REPO 格式错误: '$OWNER_REPO' (应为 owner/repo 形式)"
  exit 1
fi

# ---------------------------------------------------------------------------
# 交互模式检测
# ---------------------------------------------------------------------------
# 场景: curl | bash 时, bash 的 stdin 是 curl 的管道输出, read 拿不到终端输入
# 解决: 让 read 从 /dev/tty (控制终端) 读, 这样 pipe 模式下也能交互
# 兜底: 设置 REASONIX_NONINTERACTIVE=1 时跳过所有询问, 使用默认值

INTERACTIVE_MODE="tty"   # tty=可交互, noninteractive=用默认值

if [ "${REASONIX_NONINTERACTIVE:-0}" = "1" ]; then
  INTERACTIVE_MODE="noninteractive"
  log_warn "已启用非交互模式 (REASONIX_NONINTERACTIVE=1), 全部使用默认值"
elif [ ! -t 0 ]; then
  # stdin 不是 TTY, 典型场景: curl | bash
  if [ -e /dev/tty ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    log_info "检测到 pipe 模式 (curl | bash), 输入将从终端 /dev/tty 读取"
    INTERACTIVE_MODE="tty"
  else
    log_warn "检测到非交互环境且无法访问 /dev/tty, 将使用默认值"
    log_warn "如需交互, 请下载脚本后执行: bash install-reasonix.sh"
    INTERACTIVE_MODE="noninteractive"
  fi
fi

# 通用询问函数
# 用法: ask_prompt "提示语" 变量名 [默认值]
# 行为:
#   - 交互模式: 显示提示, 从 /dev/tty 或 stdin 读取, 空输入用默认值
#   - 非交互模式: 直接用默认值, 不询问
ask_prompt() {
  local prompt="$1"
  local var_name="$2"
  local default_val="${3:-}"

  if [ "$INTERACTIVE_MODE" = "noninteractive" ]; then
    eval "$var_name=\"\$default_val\""
    log_dim "  $prompt [默认: $default_val]"
    return 0
  fi

  local input=""
  if [ -t 0 ]; then
    # stdin 是 TTY, 直接 read
    # || true 防止 set -e 在 EOF (Ctrl+D) 时杀掉脚本
    read -p "$prompt" input || true
  else
    # stdin 是 pipe (curl | bash), 从 /dev/tty 读
    read -p "$prompt" input < /dev/tty || true
  fi

  # 应用默认值 (空输入或 Ctrl+D 时使用)
  if [ -z "$input" ]; then
    input="$default_val"
  fi
  eval "$var_name=\"\$input\""
}

# ---------------------------------------------------------------------------
# Step 1: 询问是否切换清华源
# ---------------------------------------------------------------------------
echo -e "${C_TITLE}[1/5] Termux 官方源${C_RESET}"
log_dim "  清华源 (tuna) 通常比默认源快很多 (国内尤其明显)"
ask_prompt "  是否切换到清华源? [Y/n] " switch_tsinghua "Y"

if [[ "$switch_tsinghua" =~ ^[Yy]$ ]]; then
  log_info "切换中..."
  # 幂等检查: 如果 sources.list 已经有清华源, 不重复添加
  # (用户重跑脚本时, 避免出现多行清华源 / 重复注释)
  SOURCES_LIST="$PREFIX/etc/apt/sources.list"
  TSINGHUA_URL="https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
  if grep -qF "$TSINGHUA_URL" "$SOURCES_LIST" 2>/dev/null; then
    log_ok "清华源已存在, 跳过切换"
  else
    # 把所有未注释的 deb 行注释掉, 追加清华源
    # 用临时文件 + mv 保证原子性 (sed -i 在某些 Termux 版本对 sources.list 有问题)
    TMP_SOURCES=$(mktemp)
    sed 's@^\(deb.*stable main\)$@#\1@' "$SOURCES_LIST" > "$TMP_SOURCES"
    echo "deb $TSINGHUA_URL stable main" >> "$TMP_SOURCES"
    cat "$TMP_SOURCES" > "$SOURCES_LIST"  # 不用 mv, 保留原文件权限/owner
    rm -f "$TMP_SOURCES"
    log_ok "清华源切换完成"
  fi
  apt update
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
# Step 3: 测试镜像延迟 (并发 curl)
# ---------------------------------------------------------------------------
echo ""
echo -e "${C_TITLE}[3/5] 测试镜像延迟${C_RESET}"
log_dim "  并发 curl 拉取 $(log_path "dists/${APT_DIST}/Release") (每个测 3 次取平均)..."

RELEASE_PATH="dists/${APT_DIST}/Release"

# 数组: 每个镜像的延迟 (ms), -1 = 不可达, -2 = 占位跳过
declare -a LATENCIES
best_idx=-1
best_latency=999999
valid_count=0

# 临时目录存放每个镜像的测速结果
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# 单个镜像测速函数 (后台运行, 结果写入文件)
# 参数: <索引> <url>
test_one_mirror() {
  local idx="$1"
  local url="$2"
  local result_file="$TMPDIR_TEST/result_$idx"

  # 跳过空 URL 或占位 URL
  if [ -z "$url" ] || \
     [[ "$url" == *"your-username"* ]] || \
     [[ "$url" == *"your-project"* ]] || \
     [[ "$url" == *"your-repo"* ]]; then
    echo "-2" > "$result_file"
    return
  fi

  local full_url="${url}/${RELEASE_PATH}"
  local total_ms=0
  local success=0

  for try in 1 2 3; do
    local start end ms
    start=$(date +%s%N)
    if curl -sf -o /dev/null --max-time 5 "$full_url" 2>/dev/null; then
      end=$(date +%s%N)
      ms=$(( (end - start) / 1000000 ))
      total_ms=$((total_ms + ms))
      success=$((success + 1))
    fi
  done

  if [ $success -gt 0 ]; then
    echo "$((total_ms / success))" > "$result_file"
  else
    echo "-1" > "$result_file"
  fi
}

# 启动所有镜像的测速 (并发)
log_dim "  启动 ${#MIRRORS[@]} 个并发测速任务..."
for i in "${!MIRRORS[@]}"; do
  IFS='|' read -r _ url <<< "${MIRRORS[$i]}"
  test_one_mirror "$i" "$url" &
done

# 进度条: 等待所有任务完成, 实时显示已完成数
BAR_WIDTH=24
total_mirrors=${#MIRRORS[@]}
while true; do
  done_count=$(ls "$TMPDIR_TEST"/result_* 2>/dev/null | wc -l)
  pct=$(( done_count * 100 / total_mirrors ))
  filled=$(( done_count * BAR_WIDTH / total_mirrors ))
  empty=$(( BAR_WIDTH - filled ))
  bar=""
  for ((k=0; k<filled; k++)); do bar+="█"; done
  for ((k=0; k<empty; k++)); do bar+="░"; done
  # \r 回到行首 + \033[K 清到行尾, 避免上一帧的末尾字符残留 (短串变长串时会有阴影)
  printf "\r\033[K  ${C_INFO}${bar}${C_RESET} ${C_NUMBER}%3d%%${C_RESET} ${C_DIM}(%d/%d)${C_RESET} ${C_PATH}%-20s${C_RESET}" \
    "$pct" "$done_count" "$total_mirrors" "测速中..."
  [ "$done_count" -ge "$total_mirrors" ] && break
  sleep 0.2
done
# 最后一帧: 100% 完成, 同样清行尾
printf "\r\033[K  ${C_INFO}%s${C_RESET} ${C_NUMBER}%3d%%${C_RESET} ${C_DIM}(%d/%d)${C_RESET} ${C_PATH}%-20s${C_RESET}" \
  "$bar" "100" "$total_mirrors" "$total_mirrors" "完成"
echo ""
echo ""

# 等所有后台任务结束
wait

# 收集结果
table_rows=()
for i in "${!MIRRORS[@]}"; do
  IFS='|' read -r name url <<< "${MIRRORS[$i]}"
  result_file="$TMPDIR_TEST/result_$i"
  if [ ! -f "$result_file" ]; then
    lat="-1"
  else
    lat=$(cat "$result_file")
  fi
  LATENCIES[$i]=$lat

  if [ "$lat" = "-2" ]; then
    table_rows+=("$(log_keyword "$((i+1))")|$name|$(log_dim "(跳过)")")
  elif [ "$lat" = "-1" ]; then
    table_rows+=("$(log_keyword "$((i+1))")|$name|不可达")
  else
    table_rows+=("$(log_keyword "$((i+1))")|$name|${lat}ms")
    valid_count=$((valid_count + 1))
    if [ "$lat" -lt "$best_latency" ]; then
      best_latency=$lat
      best_idx=$i
    fi
  fi
done

# 输出表格
print_table "序号|镜像名称|延迟" "${table_rows[@]}"

# 国内环境警告: GitHub 镜像 (raw.githubusercontent.com) 在国内通常延迟高
# 检查直连 GitHub 的镜像 (不含代理前缀), 只要有任意一个 > 500ms 或不可达, 就提示用 Pages/CDN/代理
warn_github=false
for i in "${!MIRRORS[@]}"; do
  lat="${LATENCIES[$i]:-0}"
  [ "$lat" = "-2" ] && continue  # 跳过被跳过的镜像
  IFS='|' read -r name url <<< "${MIRRORS[$i]}"
  # 跳过已经是代理/CDN 的镜像 (cnxiaobai/gh-proxy/jsdelivr/pages.dev)
  [[ "$url" == *"cnxiaobai"* ]] && continue
  [[ "$url" == *"gh-proxy"* ]] && continue
  [[ "$url" == *"jsdelivr"* ]] && continue
  [[ "$url" == *"pages.dev"* ]] && continue
  [[ "$url" == *"rxt.cc.cd"* ]] && continue
  [[ "$url" == *"cf.rxt"* ]] && continue
  # 只匹配直连 GitHub 的镜像
  if [[ "$url" == *"githubusercontent.com"* ]]; then
    if [ "$lat" = "-1" ] || [ "$lat" -gt 500 ]; then
      warn_github=true
      gh_name="$name"
      gh_lat_str=$([ "$lat" = "-1" ] && echo "不可达" || echo "${lat}ms")
      break
    fi
  fi
done

if [ "$warn_github" = "true" ]; then
  echo ""
  log_warn "直连 GitHub ($gh_name) 延迟较高 ($gh_lat_str)"
  echo "  $(log_dim '建议选') $(log_path 'Cloudflare Pages') $(log_dim '(cf.rxt.cc.cd) 或') $(log_path 'GitHub Pages') $(log_dim '(rxt.cc.cd)')"
fi

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
  echo "    $(log_dim '推荐使用 Cloudflare Pages (cf.rxt.cc.cd) - 国内速度最稳定')"
fi
# ask_prompt 在非交互模式下传空字符串, 这里需要特殊处理: 默认选 best_idx
if [ "$INTERACTIVE_MODE" = "noninteractive" ]; then
  if [ $best_idx -lt 0 ]; then
    log_error "非交互模式下没有可用镜像, 退出"
    exit 1
  fi
  selected=$best_idx
  log_ok "非交互模式: 已自动选择 $(log_path "${MIRRORS[$selected]%%|*}")"
else
  if [ -t 0 ]; then
    read -p "  请输入序号 (1-${#MIRRORS[@]}), 或直接回车使用推荐: " choice || true
  else
    read -p "  请输入序号 (1-${#MIRRORS[@]}), 或直接回车使用推荐: " choice < /dev/tty || true
  fi
fi

# 清理输入: 去除前后空格、回车、不可见字符
choice=$(printf '%s' "$choice" | tr -d '[:space:]')

if [ -z "$choice" ]; then
  if [ $best_idx -lt 0 ]; then
    log_error "没有可用的镜像, 退出"
    exit 1
  fi
  selected=$best_idx
  log_ok "已选择: $(log_path "${MIRRORS[$selected]%%|*}")"
else
  # 验证输入: 必须是纯数字
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    log_error "无效输入 ('$choice'), 请输入数字, 退出"
    exit 1
  fi
  selected=$((choice - 1))
  if [ $selected -lt 0 ] || [ $selected -ge ${#MIRRORS[@]} ]; then
    log_error "序号 $choice 超出范围 (1-${#MIRRORS[@]}), 退出"
    exit 1
  fi
  lat_val="${LATENCIES[$selected]:-0}"
  if [ "$lat_val" = "-1" ]; then
    log_error "该镜像 ($(log_path "${MIRRORS[$selected]%%|*}")) 不可达, 退出"
    exit 1
  elif [ "$lat_val" = "-2" ]; then
    log_error "该镜像是占位 URL ($(log_path "${MIRRORS[$selected]%%|*}")), 请先在脚本中配置"
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

# 写入源文件 - 防御性写法:
#   1. mkdir -p 父目录 (Termux 标准安装下 sources.list.d 一定存在, 但 fork 环境/精简安装可能没有)
#   2. 如果旧文件存在, 先备份 (避免覆盖用户手工配置)
#   3. touch 创建空文件 (确保文件存在, 即使 echo 失败也有个空文件可诊断)
#   4. echo 写入内容
LIST_FILE="$PREFIX/etc/apt/sources.list.d/reasonix.list"
LIST_DIR="$(dirname "$LIST_FILE")"
mkdir -p "$LIST_DIR"
if [ -f "$LIST_FILE" ]; then
  cp "$LIST_FILE" "${LIST_FILE}.bak"
  log_dim "  旧源已备份到 ${LIST_FILE}.bak"
fi
touch "$LIST_FILE"
echo "$source_line" > "$LIST_FILE"
log_ok "已写入: $LIST_FILE"
log_dim "  内容: $source_line"

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

echo ""
echo -e "${C_TITLE}临时目录${C_RESET} $(log_dim '(Termux 上 /tmp 只读, 已自动改到此处)'):"
echo -e "  $(log_path '~/.reasonix/tmp/')"
echo -e "  $(log_dim '如遇 permission denied, 运行: mkdir -p ~/.reasonix/tmp')"
