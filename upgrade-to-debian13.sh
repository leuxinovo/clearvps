#!/bin/bash
set -e

echo "==== Debian 12 → 13 升级脚本 ===="

# 更新并升级当前系统
apt update && apt -y full-upgrade

# 替换 apt 源里的 bookworm 为 trixie
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
if [ -d /etc/apt/sources.list.d ]; then
  sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*.list || true
fi

echo "==== 更新源成功，开始升级 ===="

# 更新索引并执行升级
apt update
apt -y upgrade
apt -y full-upgrade

# 自动清理不需要的软件包
apt -y autoremove --purge
apt -y clean

echo "==== 升级完成，建议重启系统 ===="
