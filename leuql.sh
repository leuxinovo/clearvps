#!/usr/bin/env bash
# ======================================================================
# 🌙 Leu Deep Clean • Ultra-Min Server Trim (Debian/Ubuntu & AlmaLinux)
# 目标：系统极简 + 深度清理 + 安全防误删 + 保留站点环境
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

# ===================== DRY RUN =====================
DRY_RUN=${DRY_RUN:-0}

run(){
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY] $*"
  else
    eval "$*"
  fi
}

# ===================== 欢迎信息 =====================
CYA="\033[36m"; C0="\033[0m"; B="\033[1m"
echo -e "${B}${CYA}==============================================${C0}"
echo -e "${B}${CYA}  🌙 欢迎使用 Leu 的清理脚本               ${C0}"
echo -e "${B}${CYA}  我的博客: https://blog.leuxx.de            ${C0}"
echo -e "${B}${CYA}==============================================${C0}"

# ===================== 美化输出 =====================
BLU="\033[38;5;33m"; GRN="\033[38;5;40m"; YEL="\033[38;5;178m"; RED="\033[38;5;196m"; GY="\033[90m"

hr(){ printf "${GY}%s${C0}\n" "────────────────────────────────────────────────────────"; }
title(){ printf "\n${B}${BLU}[%s]${C0} %s\n" "$1" "$2"; hr; }
ok(){ printf "${GRN}✔${C0} %s\n" "$*"; }
warn(){ printf "${YEL}⚠${C0} %s\n" "$*"; }
err(){ printf "${RED}✘${C0} %s\n" "$*"; }
log(){ printf "${CYA}•${C0} %s\n" "$*"; }

trap 'err "出错：行 $LINENO"; exit 1' ERR

# ===================== root 检查 =====================
if [ "$(id -u)" -ne 0 ]; then
  err "请使用 root 运行"
  exit 1
fi

# ===================== 保护路径 =====================
EXCLUDES=(
  "/www/server/panel" "/www/wwwlogs" "/www/wwwroot"
  "/www/server/nginx" "/www/server/apache" "/www/server/openresty"
  "/www/server/mysql" "/var/lib/mysql" "/var/lib/mariadb" "/var/lib/postgresql"
  "/www/server/php" "/etc/php" "/var/lib/php/sessions"
)

# ===================== 包管理识别 =====================
PKG="unknown"
command -v apt-get >/dev/null 2>&1 && PKG="apt"
command -v dnf >/dev/null 2>&1 && PKG="dnf"
command -v yum >/dev/null 2>&1 && PKG="yum"

# ===================== 记录初始空间 =====================
start_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')

# ======================================================================
title "🌍 系统概况" "系统信息与资源概览"
uname -a | sed 's/^/  /'
log "磁盘占用（根分区）："; df -h / | sed 's/^/  /'
log "内存占用："; free -h | sed 's/^/  /'
ok "概况完成"

# ======================================================================
title "🔒 进程清理" "释放锁（APT/Dpkg）"

if [ "$PKG" = "apt" ]; then
  run "pkill -9 -f 'apt|dpkg|unattended-upgrade' 2>/dev/null || true"
  run "rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock || true"
  run "dpkg --configure -a >/dev/null 2>&1 || true"
fi

ok "锁处理完成"

# ======================================================================
title "🧾 日志清理" "清空旧日志（保留结构）"

run "journalctl --rotate >/dev/null 2>&1 || true"
run "journalctl --vacuum-time=2d --vacuum-size=64M >/dev/null 2>&1 || true"

# ⚠️ 安全版日志清理（不动站点日志）
run "find /var/log \
  -type f \
  \( -name '*.log' -o -name '*.old' -o -name '*.gz' -o -name '*.1' \) \
  ! -path '/www/wwwlogs/*' \
  ! -path '/www/server/panel/logs/*' \
  -exec truncate -s 0 {} + 2>/dev/null || true"

ok "日志清理完成"

# ======================================================================
title "🧹 临时/缓存清理" "安全清理 /tmp /var/tmp"

run "find /tmp -xdev -type f -atime +2 -delete 2>/dev/null || true"
run "find /var/tmp -xdev -type f -atime +2 -delete 2>/dev/null || true"

# 不动系统关键 cache（改为包管理器清理）
if [ "$PKG" = "apt" ]; then
  run "apt-get -y autoremove --purge >/dev/null 2>&1 || true"
  run "apt-get -y autoclean >/dev/null 2>&1 || true"
  run "apt-get -y clean >/dev/null 2>&1 || true"
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  run "dnf -y clean all >/dev/null 2>&1 || yum -y clean all >/dev/null 2>&1 || true"
fi

ok "缓存清理完成"

# ======================================================================
title "✂️ 组件裁剪" "移除非必要组件"

if [ "$PKG" = "apt" ]; then
  run "apt-get -y purge snapd cloud-init cockpit cockpit-ws cockpit-system >/dev/null 2>&1 || true"
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  run "yum -y remove cloud-init cockpit cockpit-ws cockpit-system >/dev/null 2>&1 || true"
fi

ok "组件裁剪完成"

# ======================================================================
title "🧽 系统瘦身" "文档 / pyc / 静态库"

run "rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/*"

# ❗ 不再全盘 /
for d in /usr /opt /root /var/www; do
  run "find $d -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true"
  run "find $d -type f -name '*.pyc' -delete 2>/dev/null || true"
done

run "find /usr/lib /usr/lib64 /lib /lib64 -type f \( -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true"

ok "系统瘦身完成"

# ======================================================================
title "🐳 Docker 清理" "容器/镜像/卷"

if command -v docker >/dev/null 2>&1; then
  run "docker container prune -f >/dev/null 2>&1 || true"
  run "docker image prune -af >/dev/null 2>&1 || true"
  run "docker volume prune -f >/dev/null 2>&1 || true"
  ok "Docker清理完成"
else
  warn "未检测 Docker"
fi

# ======================================================================
title "🧰 内核清理" "仅保留当前内核"

if [ "$PKG" = "apt" ]; then

  CURK="$(uname -r)"

  mapfile -t KS < <(dpkg -l | awk '/linux-image-[0-9]/{print $2}')

  if [ ${#KS[@]} -eq 0 ]; then
    warn "未检测内核包，跳过"
  else
    PURGE=()

    for k in "${KS[@]}"; do
      [[ "$k" == *"$CURK"* ]] && continue
      PURGE+=("$k")
    done

    if [ ${#PURGE[@]} -gt 0 ]; then
      run "apt-get -y purge ${PURGE[*]} >/dev/null 2>&1 || true"
    fi
  fi

elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  CURK="$(uname -r)"
  run "rpm -q kernel | grep -v \"$CURK\" | xargs -r yum -y remove >/dev/null 2>&1 || true"
fi

ok "内核清理完成"

# ======================================================================
title "⚡ 内存优化" "低负载回收缓存"

LOAD1=$(awk '{print int($1)}' /proc/loadavg)
MEM_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
MEM_TOTAL_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
PCT=$(( MEM_AVAIL_KB*100 / MEM_TOTAL_KB ))

if (( LOAD1 <= 2 && PCT >= 30 )); then
  log "执行内存回收"
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  ok "内存优化完成"
else
  warn "跳过内存优化"
fi

# ======================================================================
title "🪶 磁盘 TRIM" "SSD优化"

command -v fstrim >/dev/null 2>&1 && run "fstrim -av >/dev/null 2>&1 || true" && ok "TRIM完成" || warn "未支持TRIM"

# ======================================================================
title "📊 汇总报告" "清理后状态"

df -h /
free -h

# ======================================================================
end_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')
cleared_bytes=$(( end_space - start_space ))
[ $cleared_bytes -lt 0 ] && cleared_bytes=0

if [ $cleared_bytes -lt 1048576 ]; then
  cleared="0 MB"
elif [ $cleared_bytes -lt 1073741824 ]; then
  cleared=$(awk "BEGIN {printf \"%.1f MB\", $cleared_bytes/1048576}")
else
  cleared=$(awk "BEGIN {printf \"%.2f GB\", $cleared_bytes/1073741824}")
fi

title "✨ 清理完成" "释放空间约 ${cleared}"
