#!/usr/bin/env bash
# ======================================================================
# 🌙 Leu清理脚本 • Ultra-Min Server Trim (Debian/Ubuntu & AlmaLinux)
# 目标：在不影响 BT/站点/DB/PHP/SSH 的前提下，尽可能“系统极简 + 深度清理”
# 并增加 Docker 清理支持
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

# ====== 美观输出 ======
C0="\033[0m"; B="\033[1m"; BLU="\033[38;5;33m"; GRN="\033[38;5;40m"; YEL="\033[38;5;178m"; RED="\033[38;5;196m"; CYA="\033[36m"; GY="\033[90m"

hr(){ printf "${GY}%s${C0}\n" "────────────────────────────────────────────────────────"; }

# ====== title 函数美化（左右紧贴，无多余空格） ======
title(){ printf "\n${B}${BLU}[%s]${C0} %s\n" "$1" "$2"; hr; }

ok(){ printf "${GRN}✔${C0} %s\n" "$*"; }
warn(){ printf "${YEL}⚠${C0} %s\n" "$*"; }
err(){ printf "${RED}✘${C0} %s\n" "$*"; }
log(){ printf "${CYA}•${C0} %s\n" "$*"; }

trap 'err "出错：行 $LINENO"; exit 1' ERR

# ====== 欢迎信息 ======
hr
echo -e "${B}${BLU}欢迎使用 Leu清理脚本${C0}"
echo -e "${B}${CYA}我的博客：https://blog.leuxx.de${C0}"
hr

# ====== 保护路径（绝不触碰）======
EXCLUDES=(
  "/www/server/panel" "/www/wwwlogs" "/www/wwwroot"
  "/www/server/nginx" "/www/server/apache" "/www/server/openresty"
  "/www/server/mysql" "/var/lib/mysql" "/var/lib/mariadb" "/var/lib/postgresql"
  "/www/server/php" "/etc/php" "/var/lib/php/sessions"
)
is_excluded(){ local p="$1"; for e in "${EXCLUDES[@]}"; do [[ "$p" == "$e"* ]] && return 0; done; return 1; }

# ====== 工具与平台识别 =======
PKG="unknown"
if command -v apt-get >/dev/null 2>&1; then
  PKG="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG="yum"
fi

is_vm(){ command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet; }
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

# ====== 系统概况 =======
title "🌍 系统概况" "系统信息与资源概览"
uname -a | sed 's/^/  /'
log "磁盘占用（根分区）："; df -h / | sed 's/^/  /'
log "内存占用："; free -h | sed 's/^/  /'
ok "概况完成"

# ====== 清理前记录磁盘可用空间 =======
start_space=$(df --output=avail / | tail -n1 | tr -dc '0-9')
start_space=${start_space:-0}

# ====== APT/Dpkg 锁处理 =======
if [ "$PKG" = "apt" ]; then
  title "🔒 进程清理" "释放 APT/Dpkg 锁"
  pkill -9 -f 'apt|apt-get|dpkg|unattended-upgrade' 2>/dev/null || true
  rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock || true
  dpkg --configure -a >/dev/null 2>&1 || true
  ok "apt/dpkg 锁处理完成"
fi

# ====== 日志清理 =======
title "🧾 日志清理" "清空旧日志 保留结构"
journalctl --rotate || true
journalctl --vacuum-time=1d --vacuum-size=64M >/dev/null 2>&1 || true
NI "find /var/log -type f \( -name '*.log' -o -name '*.old' -o -name '*.gz' -o -name '*.1' \) \
  -not -path '/www/server/panel/logs/*' -not -path '/www/wwwlogs/*' -exec truncate -s 0 {} + 2>/dev/null || true"
: > /var/log/wtmp  || true; : > /var/log/btmp  || true; : > /var/log/lastlog || true; : > /var/log/faillog || true
ok "日志清理完成"

# ====== 临时/缓存清理 =======
title "🧹 缓存清理" "清理 /tmp /var/tmp /var/cache 等"
NI "find /tmp -xdev -type f -atime +1 -not -name 'sess_*' -delete 2>/dev/null || true"
NI "find /var/tmp -xdev -type f -atime +1 -delete 2>/dev/null || true"
NI "find /var/cache -xdev -type f -mtime +1 -delete 2>/dev/null || true"
rm -rf /var/crash/* /var/lib/systemd/coredump/* 2>/dev/null || true
rm -rf /var/lib/nginx/tmp/* /var/lib/nginx/body/* /var/lib/nginx/proxy/* /var/tmp/nginx/* /var/cache/nginx/* 2>/dev/null || true
ok "临时/缓存清理完成"

# ====== 包缓存 & 历史 =======
title "📦 包缓存" "APT/DNF 历史与缓存深度清理"
if [ "$PKG" = "apt" ]; then
  apt-get -y autoremove --purge >/dev/null 2>&1 || true
  apt-get -y autoclean >/dev/null 2>&1 || true
  apt-get -y clean >/dev/null 2>&1 || true
  dpkg -l 2>/dev/null | awk '/^rc/{print $2}' | xargs -r dpkg -P >/dev/null 2>&1 || true
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  (dnf -y autoremove >/dev/null 2>&1 || yum -y autoremove >/dev/null 2>&1 || true)
  (dnf -y clean all >/dev/null 2>&1 || yum -y clean all >/dev/null 2>&1 || true)
fi
ok "包缓存/历史清理完成"

# ====== 系统瘦身 =======
title "🧽 系统瘦身" "文档/本地化/静态库/pyc"
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/* 2>/dev/null || true
if [[ -d /usr/share/locale ]]; then
  find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
    | grep -Ev '^(.*\/)?(en|zh)' | xargs -r rm -rf 2>/dev/null || true
fi
NI "find / -xdev -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true"
NI "find / -xdev -type f -name '*.pyc' -delete 2>/dev/null || true"
ok "系统瘦身完成"

# ====== Docker 清理 =======
title "🐳 Docker清理" "清理未使用的镜像、容器、卷"
if command -v docker >/dev/null 2>&1; then
    docker system prune -af --volumes >/dev/null 2>&1 || true
    ok "Docker清理完成"
else
    warn "未检测到Docker 跳过"
fi

# ====== 清理后记录磁盘可用空间 =======
end_space=$(df --output=avail / | tail -n1 | tr -dc '0-9')
end_space=${end_space:-0}

# ====== 计算释放空间 =======
cleared_kb=$(( end_space - start_space ))
[ $cleared_kb -lt 0 ] && cleared_kb=0

# ====== 美化输出：星星 ✨ + 清理完成 + 释放空间 =====
if [ "$cleared_kb" -eq 0 ]; then
    title "✨ Leu 清理脚本执行完成" "释放空间约 0 MB"
elif [ "$cleared_kb" -ge 1048576 ]; then
    cleared_gb=$(awk "BEGIN {printf \"%.2f\", $cleared_kb/1048576}")
    title "✨ Leu 清理脚本执行完成" "释放空间约 ${cleared_gb} GB"
else
    cleared_mb=$(awk "BEGIN {printf \"%.2f\", $cleared_kb/1024}")
    title "✨ Leu 清理脚本执行完成" "释放空间约 ${cleared_mb} MB"
fi
