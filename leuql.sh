#!/bin/bash
#颜色代码
orange="\033[38;5;208m"
echo "${orange}欢迎使用Leu的清理脚本${reset}"

# 确保脚本以root权限运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

# 记录开始时的磁盘空间
start_space=$(df / | tail -n 1 | awk '{print $3}')

# 更新依赖
echo "正在更新依赖..."
apt-get update > /dev/null 2>&1
apt-get install -y deborphan > /dev/null 2>&1

# 安全删除旧内核
echo "正在删除未使用的内核..."
current_kernel=$(uname -r)
kernel_packages=$(dpkg --list | grep -E '^ii  linux-(image|headers)-[0-9]+' | awk '{ print $2 }' | grep -v "$current_kernel")
if [ ! -z "$kernel_packages" ]; then
    echo "找到旧内核，正在删除：$kernel_packages"
    apt-get purge -y $kernel_packages > /dev/null 2>&1 || echo "删除旧内核时出现错误"
    update-grub > /dev/null 2>&1 || echo "更新GRUB时出现错误"
else
    echo "没有旧内核需要删除。"
fi

# 清理孤立的包
echo "正在清理孤立的包..."
deborphan | xargs -r apt-get -y remove --purge > /dev/null 2>&1

# 清理系统日志文件
echo "正在清理系统日志文件..."
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1
find /root -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1

# 清理缓存目录
echo "正在清理缓存目录..."
rm -rf /tmp/* /var/tmp/* ~/.cache/pip > /dev/null 2>&1

# 清理用户缓存目录
echo "正在清理用户缓存目录..."
for user_cache in /home/*/".cache"; do
  if [ -d "$user_cache" ]; then
    rm -rf "$user_cache/*" > /dev/null 2>&1 || echo "清理用户缓存时出现错误"
  fi
done

# 清理APT的本地存档
echo "正在清理APT的本地存档..."
rm -rf /var/cache/apt/archives/* > /dev/null 2>&1

# 清理Docker（如果使用Docker）
if command -v docker &> /dev/null; then
    echo "正在清理Docker镜像、容器和卷..."
    docker system prune -a -f --volumes > /dev/null 2>&1
fi

# 清理包管理器缓存
echo "正在清理包管理器缓存..."
apt-get autoclean > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1
apt-get clean > /dev/null 2>&1

# 计算清理后的磁盘空间
end_space=$(df / | tail -n 1 | awk '{print $3}')
cleared_space=$((start_space - end_space))
echo "系统清理完成，清理了 $((cleared_space / 1024))M 空间！"
