#!/bin/bash

# 一键切换 TCP 拥塞控制为 CUBIC 并立即生效

echo "=== 切换 TCP 拥塞控制为 CUBIC ==="

# 备份 sysctl 配置文件
cp /etc/sysctl.conf /etc/sysctl.conf.bak_$(date +%F_%T)

# 设置队列调度器
sysctl -w net.core.default_qdisc=pfifo_fast

# 设置拥塞控制为 CUBIC
sysctl -w net.ipv4.tcp_congestion_control=cubic

# 永久生效（写入 sysctl.conf）
grep -q "net.core.default_qdisc" /etc/sysctl.conf && \
    sed -i "s/^net.core.default_qdisc=.*/net.core.default_qdisc=pfifo_fast/" /etc/sysctl.conf || \
    echo "net.core.default_qdisc=pfifo_fast" >> /etc/sysctl.conf

grep -q "net.ipv4.tcp_congestion_control" /etc/sysctl.conf && \
    sed -i "s/^net.ipv4.tcp_congestion_control=.*/net.ipv4.tcp_congestion_control=cubic/" /etc/sysctl.conf || \
    echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf

# 应用 sysctl 配置（立即生效）
sysctl -p > /dev/null 2>&1

# 检查结果
CURRENT_QDISC=$(sysctl net.core.default_qdisc | awk '{print $3}')
CURRENT_CC=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

echo "✅ 当前队列调度器: $CURRENT_QDISC"
echo "✅ 当前 TCP 拥塞控制: $CURRENT_CC"

echo "=== 完成 ==="
