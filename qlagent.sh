#!/bin/bash

# 停止 Nezha Agent 服务
echo "正在停止 Nezha Agent 服务..."
systemctl stop nezha-agent 2>/dev/null || echo "Nezha Agent 服务未运行。"

# 禁用开机自动启动
echo "正在禁用 Nezha Agent 开机自动启动..."
systemctl disable nezha-agent 2>/dev/null || echo "Nezha Agent 未设置为开机启动。"

# 删除 Nezha Agent 二进制文件
if [ -d "/opt/nezha/agent" ]; then
    echo "正在删除 Nezha Agent 二进制文件..."
    rm -rf /opt/nezha/agent
    echo "二进制文件已删除。"
else
    echo "未在 /opt/nezha/agent 目录中找到 Nezha Agent 二进制文件。"
fi

# 删除 Nezha Agent 服务文件
if [ -f "/etc/systemd/system/nezha-agent.service" ]; then
    echo "正在删除 Nezha Agent 服务文件..."
    rm /etc/systemd/system/nezha-agent.service
    echo "服务文件已删除。"
else
    echo "未在 /etc/systemd/system 中找到 Nezha Agent 服务文件。"
fi

# 重新加载 systemd 配置
echo "正在重新加载 systemd 守护进程配置..."
systemctl daemon-reload

echo "Nezha Agent 已成功移除。"
