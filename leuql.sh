#!/bin/bash

# 颜色代码
blue="\033[34m"
reset="\033[0m"

# 欢迎信息
echo -e "${blue}欢迎使用 Leu清理脚本${reset}"
echo -e "${blue}我的博客：https://blog.leuxx.de${reset}"

# 确保以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo "❌ 此脚本必须以 root 权限运行"
   exit 1
fi

# 记录清理前的可用磁盘空间（单位：KB）
start_space=$(df --output=avail / | tail -n 1)

# 更新依赖和安装 deborphan
echo "▶ 正在更新依赖..."
apt-get update -qq > /dev/null
apt-get install -y deborphan > /dev/null 2>&1

# 删除未使用的旧内核
echo "▶ 正在删除未使用的旧内核..."
current_kernel=$(uname -r)
kernel_packages=$(dpkg --list | grep -E '^ii  linux-(image|headers)-[0-9]+' | awk '{ print $2 }' | grep -v "$current_kernel")
if [[ -n "$kernel_packages" ]]; then
    echo "🧹 删除内核包：$kernel_packages"
    apt-get purge -y $kernel_packages > /dev/null 2>&1 || echo "⚠️ 删除旧内核时出错"
    update-grub > /dev/null 2>&1 || echo "⚠️ 更新 GRUB 时出错"
else
    echo "✅ 没有旧内核需要删除"
fi

# 清理孤立包
echo "▶ 正在清理孤立包..."
deborphan | xargs -r apt-get -y remove --purge > /dev/null 2>&1

# 清理日志
echo "▶ 正在清理系统日志文件..."
find /var/log -type f -exec truncate -s 0 {} \; > /dev/null 2>&1
find /root -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1

# 清理 journal 日志（彻底）
if command -v journalctl > /dev/null; then
  echo "▶ 正在清理 journalctl 日志..."
  journalctl --rotate >/dev/null 2>&1
  journalctl --vacuum-time=1s >/dev/null 2>&1
fi

# 清理缓存目录
echo "▶ 正在清理缓存目录..."
rm -rf /tmp/* /var/tmp/* ~/.cache/pip > /dev/null 2>&1

# 清理用户缓存目录
echo "▶ 正在清理用户缓存目录..."
for user_cache in /home/*/".cache"; do
  if [ -d "$user_cache" ]; then
    rm -rf "$user_cache"/* > /dev/null 2>&1 || echo "⚠️ 清理 $user_cache 时出错"
  fi
done

# 清理 APT 缓存
echo "▶ 正在清理 APT 缓存..."
rm -rf /var/cache/apt/archives/* > /dev/null 2>&1
apt-get autoclean -qq > /dev/null
apt-get autoremove -y > /dev/null 2>&1
apt-get clean > /dev/null 2>&1

# 清理 Docker
if command -v docker &> /dev/null; then
    echo "▶ 正在清理 Docker 镜像、容器和卷..."
    docker system prune -a -f --volumes > /dev/null 2>&1
fi

# 计算清理后的磁盘可用空间（单位：KB）
end_space=$(df --output=avail / | tail -n 1)
cleared_kb=$((end_space - start_space))

# 智能单位输出，紧贴上面输出
if [ "$cleared_kb" -ge 1048576 ]; then
    cleared_gb=$(awk "BEGIN {printf \"%.2f\", $cleared_kb/1048576}")
    echo -e "🧹 系统清理完成，释放了约 ${cleared_gb} GB 空间"
else
    cleared_mb=$((cleared_kb / 1024))
    echo -e "🧹 系统清理完成，释放了约 ${cleared_mb} MB 空间"
fi
