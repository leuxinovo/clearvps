#!/usr/bin/env bash
# ======================================================================
# 🌙 Leu Deep Clean • Ultra-Min Server Trim (Debian/Ubuntu & AlmaLinux)
# 目标：在不影响 BT/站点/DB/PHP/SSH 的前提下，尽可能“系统极简 + 深度清理”
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_PATH="/root/deep-clean.sh"

# ====== 美观输出 ======
C0="\033[0m"; B="\033[1m"; BLU="\033[38;5;33m"; GRN="\033[38;5;40m"; YEL="\033[38;5;178m"; RED="\033[38;5;196m"; CYA="\033[36m"; GY="\033[90m"
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

# ======================================================================
title "🧽 系统瘦身" "文档/本地化/pyc/静态库"
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/* 2>/dev/null || true
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d | grep -Ev 'en|zh' | xargs -r rm -rf 2>/dev/null || true
NI "find / -xdev -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true"
NI "find / -xdev -type f -name '*.pyc' -delete 2>/dev/null || true"
ok "系统瘦身完成"

# ======================================================================
title "🐳 Docker 清理" "清理未使用镜像/容器/卷"
if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes >/dev/null 2>&1 || true
  ok "Docker清理完成"
else
  warn "未检测到 Docker，跳过"
fi

# ======================================================================
title "💾 Swap 管理" "自动配置 swap"
MEM_MB="$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)"
if [[ "$MEM_MB" -ge 2048 ]]; then
  warn "内存 ≥ 2G，禁用 swap"
  swapoff -a || true
else
  SWAPFILE="/swapfile"
  [[ -f "$SWAPFILE" ]] || fallocate -l $((MEM_MB/2))M "$SWAPFILE"
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE" >/dev/null || true
  swapon "$SWAPFILE" || true
  ok "单一 swap 文件启用：$SWAPFILE"
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
hr

# ======================================================================
title "⏰ 自动任务" "每日凌晨 03:00 自动运行"
chmod +x "$SCRIPT_PATH"
( crontab -u root -l 2>/dev/null | grep -v 'deep-clean.sh' || true; echo "0 3 * * * /bin/bash $SCRIPT_PATH >/dev/null 2>&1" ) | crontab -u root -
ok "已设置每日 03:00 自动清理"
