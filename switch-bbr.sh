#!/bin/bash

CONF_FILE="/etc/sysctl.d/99-sysctl.conf"

# 检查当前算法
CURRENT=$(sysctl -n net.ipv4.tcp_congestion_control)

if [ "$CURRENT" = "bbr" ]; then
    echo "当前使用的是 BBR，切换到 Cubic..."
    echo "net.ipv4.tcp_congestion_control = cubic" | sudo tee $CONF_FILE > /dev/null
else
    echo "当前使用的是 $CURRENT，切换到 BBR..."
    echo "net.ipv4.tcp_congestion_control = bbr" | sudo tee $CONF_FILE > /dev/null
fi

# 应用配置
sudo sysctl --system

# 验证结果
NEW=$(sysctl -n net.ipv4.tcp_congestion_control)
echo "已切换完成，现在使用：$NEW"
