#!/usr/bin/env bash
# ======================================================================
# 🌙 Leu Deep Clean • SAFE v3 (FIXED)
# 修复点：
# 1. 彻底解决 unbound variable
# 2. 防止误删内核
# 3. 所有变量安全展开
# 4. 可在 Debian/Ubuntu/CentOS 使用
# ======================================================================

set -euo pipefail
IFS=$'\n\t'

# ================= 输出 =================
CYA="\033[36m"; C0="\033[0m"; B="\033[1m"
BLU="\033[38;5;33m"; GRN="\033[38;5;40m"; YEL="\033[38;5;178m"; RED="\033[38;5;196m"; GY="\033[90m"

hr(){ printf "${GY}%s${C0}\n" "────────────────────────────────────"; }

title(){
  local a="${1:-}"
  local b="${2:-}"
  printf "\n${B}${BLU}[%s]${C0} %s\n" "$a" "$b"
  hr
}

ok(){ printf "${GRN}✔${C0} %s\n" "${1:-}"; }
warn(){ printf "${YEL}⚠${C0} %s\n" "${1:-}"; }
err(){ printf "${RED}✘${C0} %s\n" "${1:-}"; }

trap 'err "脚本错误，行 $LINENO"; exit 1' ERR

# ================= 包管理器 =================
PKG="unknown"
command -v apt-get >/dev/null 2>&1 && PKG="apt"
command -v dnf >/dev/null 2>&1 && PKG="dnf"
command -v yum >/dev/null 2>&1 && PKG="yum"

# ================= 起始空间 =================
start_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')

# ======================================================================
title "系统信息" "基础状态"
uname -a || true
df -h / || true
free -h || true

# ======================================================================
title "APT锁清理" "安全处理"

if [ "$PKG" = "apt" ]; then
  pkill -f apt-get 2>/dev/null || true
  rm -f /var/lib/dpkg/lock* /var/cache/apt/archives/lock 2>/dev/null || true
  dpkg --configure -a >/dev/null 2>&1 || true
  ok "APT锁已清理"
fi

# ======================================================================
title "日志清理" "安全模式"

journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=2d >/dev/null 2>&1 || true

find /var/log -type f \
  \( -name "*.log" -o -name "*.gz" -o -name "*.1" -o -name "*.old" \) \
  -exec truncate -s 0 {} + 2>/dev/null || true

ok "日志清理完成"

# ======================================================================
title "缓存清理" "安全模式"

find /tmp -type f -atime +2 -delete 2>/dev/null || true
find /var/tmp -type f -atime +2 -delete 2>/dev/null || true
rm -rf /var/crash/* 2>/dev/null || true

if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes >/dev/null 2>&1 || true
fi

ok "缓存清理完成"

# ======================================================================
title "包清理" "APT/DNF"

if [ "$PKG" = "apt" ]; then
  apt-get autoremove -y --purge >/dev/null 2>&1 || true
  apt-get autoclean -y >/dev/null 2>&1 || true
  apt-get clean -y >/dev/null 2>&1 || true
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  (dnf -y autoremove || yum -y autoremove || true)
  (dnf -y clean all || yum -y clean all || true)
fi

ok "包清理完成"

# ======================================================================
title "组件清理" "轻量优化"

if [ "$PKG" = "apt" ]; then
  apt-get remove -y snapd cockpit cloud-init >/dev/null 2>&1 || true
elif [ "$PKG" = "dnf" ] || [ "$PKG" = "yum" ]; then
  (dnf remove -y cockpit cloud-init || yum remove -y cockpit cloud-init || true)
fi

ok "组件清理完成"

# ======================================================================
title "系统瘦身" "安全删除"

rm -rf /usr/share/man/* 2>/dev/null || true
rm -rf /usr/share/info/* 2>/dev/null || true
rm -rf /usr/share/doc/* 2>/dev/null || true

find /usr -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find /usr -type f -name "*.pyc" -delete 2>/dev/null || true

ok "瘦身完成"

# ======================================================================
title "🚨 内核处理" "绝对安全版（不会删系统）"

CURK="$(uname -r 2>/dev/null || true)"

if [ "$PKG" = "apt" ]; then

  mapfile -t KERNELS < <(dpkg-query -W -f='${Package}\n' 'linux-image-*' 2>/dev/null || true)

  if [ ${#KERNELS[@]} -eq 0 ]; then
    warn "未检测到内核包，跳过（防炸）"
  else

    KEEP_CUR="linux-image-${CURK}"
    KEEP_LATEST="$(printf "%s\n" "${KERNELS[@]}" | sort -V | tail -n1 || true)"

    PURGE=()

    for k in "${KERNELS[@]}"; do
      [[ "$k" == *"$KEEP_CUR"* ]] && continue
      [[ "$k" == "$KEEP_LATEST" ]] && continue
      PURGE+=("$k")
    done

    if [ ${#PURGE[@]} -gt 0 ]; then
      warn "准备删除旧内核: ${PURGE[*]}"
      apt-get purge -y "${PURGE[@]}" >/dev/null 2>&1 || true
    else
      ok "无可清理内核"
    fi

  fi
fi

ok "内核处理完成"

# ======================================================================
title "磁盘 TRIM" "SSD优化"

command -v fstrim >/dev/null 2>&1 && fstrim -av >/dev/null 2>&1 || warn "无 fstrim"

# ======================================================================
title "最终状态" "统计"

df -h / || true
free -h || true

end_space=$(df --output=avail -B1 / | tail -n1 | tr -dc '0-9')

cleared=$(( end_space - start_space ))
[ $cleared -lt 0 ] && cleared=0

if [ $cleared -lt 1048576 ]; then
  size="0 MB"
elif [ $cleared -lt 1073741824 ]; then
  size="$(awk "BEGIN{printf \"%.1f MB\", $cleared/1048576}")"
else
  size="$(awk "BEGIN{printf \"%.2f GB\", $cleared/1073741824}")"
fi

title "完成" "释放空间约 ${size}"
