#!/usr/bin/env bash
# ======================================================================
# 🌙 Leu Deep Clean • Ultra-Min Server Trim (Debian/Ubuntu & AlmaLinux)
# 目标：在不影响 BT/站点/DB/PHP/SSH 的前提下，尽可能“系统极简 + 深度清理”
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

# ====== 欢迎信息 / 博客 ======
CYA="\033[36m"; C0="\033[0m"; B="\033[1m"
echo -e "${B}${CYA}==============================================${C0}"
echo -e "${B}${CYA}  欢迎使用 Leu 的清理脚本                  ${C0}"
echo -e "${B}${CYA}  我的博客: https://blog.leuxx.de            ${C0}"
echo -e "${B}${CYA}==============================================${C0}"

# ====== 美观输出 ======
BLU="\033[38;5;33m"; GRN="\033[38;5;40m"; YEL="\033[38;5;178m"; RED="\033[38;5;196m"; GY="\033[90m"
hr(){ printf "${GY}%s${C0}\n" "────────────────────────────────────────────────────────"; }
title(){ printf "\n${B}${BLU}[%s]${C0} %s\n" "$1" "$2"; hr; }
ok(){ printf "${GRN}✔${C0} %s\n" "$*"; }
warn(){ printf "${YEL}⚠${C0} %s\n" "$*"; }
err(){ printf "${RED}✘${C0} %s\n" "$*"; }
log(){ printf "${CYA}•${C0} %s\n" "$*"; }
trap 'err "出错：行 $LINENO"; exit 1' ERR

# ====== 保护路径（绝不触碰）======
EXCLUDES=(
  "/www/server/panel" "/www/wwwlogs" "/www/wwwroot"
  "/www/server/nginx" "/www/server/apache" "/www/server/openresty"
  "/www/server/mysql" "/var/lib/mysql" "/var/lib/mariadb" "/var/lib/postgresql"
  "/www/server/php" "/etc/php" "/var/lib/php/sessions"
)
is_excluded(){ local p="$1"; for e in "${EXCLUDES[@]}"; do [[ "$p" == "$e"* ]] && return 0; done; return 1; }

# ====== 工具识别 ======
PKG="unknown"
if command -v apt-get >/dev/null 2>&1; then PKG="apt"
elif command -v dnf >/dev/null 2>&1; then PKG="dnf"
elif command -v yum >/dev/null 2>&1; then PKG="yum"
fi
NI(){ nice -n 19 ionice -c3 bash -c "$*"; }

dpkg_has(){ dpkg -s "$1" >/dev/null 2>&1; }
rpm_has(){ rpm -q "$1" >/dev/null 2>&1; }

pkg_purge(){
  for p in "$@"; do
    case "$PKG" in
      apt)
        dpkg_has "$p" && apt-get -y purge "$p" >/dev/null 2>&1 || true
        ;;
      dnf|yum)
        rpm_has "$p" && (dnf -y remove "$p" >/dev/null 2>&1 || yum -y remove "$p" >/dev/null 2>&1) || true
        ;;
    esac
  done
}

# ====== 记录初始空间 ======
start_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')

# ======================================================================
title "🌍 系统概况" "系统信息与资源概览"
uname -a | sed 's/^/  /'
log "磁盘占用（根分区）："; df -h / | sed 's/^/  /'
log "内存占用："; free -h | sed 's/^/  /'
ok "概况完成"

# ======================================================================
if [ "$PKG" = "apt" ]; then
  title "🔒 进程清理" "释放 APT/Dpkg 锁"
  pkill -9 -f 'apt|apt-get|dpkg|unattended-upgrade' 2>/dev/null || true
  rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock || true
  dpkg --configure -a >/dev/null 2>&1 || true
  ok "apt/dpkg 锁处理完成"
fi

# ======================================================================
title "🧾 日志清理" "清空旧日志 保留结构"
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=1d --vacuum-size=64M >/dev/null 2>&1 || true
NI "find /var/log -type f \( -name '*.log' -o -name '*.old' -o -name '*.gz' -o -name '*.1' \) \
  -not -path '/www/server/panel/logs/*' -not -path '/www/wwwlogs/*' -exec truncate -s 0 {} + 2>/dev/null || true"
: > /var/log/wtmp  || true; : > /var/log/btmp  || true; : > /var/log/lastlog || true; : > /var/log/faillog || true
ok "日志清理完成"

# ======================================================================
title "🧹 临时/缓存清理" "清理 /tmp /var/tmp /var/cache"
NI "find /tmp -xdev -type f -atime +1 -delete 2>/dev/null || true"
NI "find /var/tmp -xdev -type f -atime +1 -delete 2>/dev/null || true"
NI "find /var/cache -xdev -type f -mtime +1 -delete 2>/dev/null || true"
rm -rf /var/crash/* /var/lib/systemd/coredump/* 2>/dev/null || true
rm -rf /var/lib/nginx/tmp/* /var/lib/nginx/body/* /var/lib/nginx/proxy/* /var/tmp/nginx/* /var/cache/nginx/* 2>/dev/null || true
ok "临时/缓存清理完成"

# ======================================================================
title "📦 包缓存清理" "APT/DNF 历史与缓存"
if [ "$PKG" = "apt" ]; then
  apt-get -y autoremove --purge >/dev/null 2>&1 || true
  apt-get -y autoclean >/dev/null 2>&1 || true
  apt-get -y clean >/dev/null 2>&1 || true
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  (dnf -y autoremove >/dev/null 2>&1 || yum -y autoremove >/dev/null 2>&1 || true)
  (dnf -y clean all >/dev/null 2>&1 || yum -y clean all >/dev/null 2>&1 || true)
fi
ok "包缓存/历史清理完成"

# ======================================================================
title "✂️ 组件裁剪" "移除非必需组件"
if [ "$PKG" = "apt" ]; then
  pkg_purge snapd cloud-init cockpit cockpit-ws cockpit-system
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  pkg_purge cloud-init subscription-manager cockpit cockpit-ws cockpit-system
fi
ok "组件裁剪完成"

# ====== 文档/开发静态库/pyc 瘦身（不删除语言文件） ======
title "🧽 系统瘦身" "文档/静态库/pyc"
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/* 2>/dev/null || true
NI "find / -xdev -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true"
NI "find / -xdev -type f -name '*.pyc' -delete 2>/dev/null || true"
NI "find /usr/lib /usr/lib64 /lib /lib64 -type f \( -name '*.a' -o -name '*.la' \) -delete 2>/dev/null || true"
ok "系统瘦身完成"

# ======================================================================
title "🐳 Docker 清理" "清理未使用镜像/容器/卷"
if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes >/dev/null 2>&1 || true
  ok "Docker清理完成"
else
  warn "未检测到 Docker，跳过"
fi

# ====== 旧内核（保留当前）======
title "🧰 内核清理" "仅保留当前正在使用的内核"

CURR_KERNEL="$(uname -r)"

if [ "$PKG" = "apt" ]; then
  # 获取所有已安装内核包
  INSTALLED_KERNELS=$(dpkg -l | awk '/linux-image-[0-9]/{print $2}')

  PURGE_LIST=()

  for k in $INSTALLED_KERNELS; do
    # 当前运行内核对应包不删
    if [[ "$k" == *"$CURR_KERNEL"* ]]; then
      continue
    fi
    PURGE_LIST+=("$k")
  done

  if [ ${#PURGE_LIST[@]} -gt 0 ]; then
    NI apt-get -y purge "${PURGE_LIST[@]}" >/dev/null 2>&1 || true
  fi

elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  # RHEL系：保留当前 kernel
  mapfile -t OLD_KERNELS < <(rpm -q kernel kernel-core 2>/dev/null | grep -v "$CURR_KERNEL" || true)

  if [ ${#OLD_KERNELS[@]} -gt 0 ]; then
    (dnf -y remove "${OLD_KERNELS[@]}" >/dev/null 2>&1 || yum -y remove "${OLD_KERNELS[@]}" >/dev/null 2>&1 || true)
  fi
fi

ok "内核清理完成（已保留当前运行内核: $CURR_KERNEL）"

# ====== 内存/CPU 优化（深度）======
title "⚡ 内存优化" "低负载回收缓存"
LOAD1=$(awk '{print int($1)}' /proc/loadavg)
MEM_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
MEM_TOTAL_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
PCT=$(( MEM_AVAIL_KB*100 / MEM_TOTAL_KB ))
if (( LOAD1 <= 2 && PCT >= 30 )); then
  log "条件满足(Load1=${LOAD1}, MemAvail=${PCT}%)，执行回收"
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
  [[ -w /proc/sys/vm/compact_memory ]] && echo 1 > /proc/sys/vm/compact_memory || true
  sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
  ok "内存/CPU 回收完成"
else
  warn "跳过回收（Load1=${LOAD1}, MemAvail=${PCT}%），避免卡顿/断连"
fi

# ======================================================================
title "🪶 磁盘 TRIM" "提升 SSD 性能"
command -v fstrim >/dev/null 2>&1 && NI "fstrim -av >/dev/null 2>&1 || true" && ok "fstrim 完成" || warn "未检测到 fstrim"

# ======================================================================
title "📊 汇总报告" "清理后资源状态"
df -h / | sed 's/^/  /'
free -h | sed 's/^/  /'

# ======================================================================
end_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')
cleared_bytes=$(( end_space - start_space ))
[ $cleared_bytes -lt 0 ] && cleared_bytes=0
if [ $cleared_bytes -lt 1048576 ]; then
  cleared="0 MB"
elif [ $cleared_bytes -lt 1073741824 ]; then
  cleared_mb=$(awk "BEGIN {printf \"%.1f\", $cleared_bytes/1048576}")
  cleared="${cleared_mb} MB"
else
  cleared_gb=$(awk "BEGIN {printf \"%.2f\", $cleared_bytes/1073741824}")
  cleared="${cleared_gb} GB"
fi
title "✨ Leu 清理脚本执行完成" "释放空间约 ${cleared}"
