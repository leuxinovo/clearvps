#!/bin/bash

# 停止 Nezha Agent 服务
echo "Stopping Nezha Agent service..."
systemctl stop nezha-agent 2>/dev/null || echo "Nezha Agent service is not running."

# 禁用开机自动启动
echo "Disabling Nezha Agent from starting at boot..."
systemctl disable nezha-agent 2>/dev/null || echo "Nezha Agent service is not enabled at boot."

# 删除 Nezha Agent 二进制文件
if [ -d "/opt/nezha" ]; then
    echo "Removing Nezha Agent binary files..."
    rm -rf /opt/nezha/agent
    echo "Binary files removed."
else
    echo "No Nezha Agent binary files found in /opt/nezha/agent."
fi

# 删除 Nezha Agent 服务文件
if [ -f "/etc/systemd/system/nezha-agent.service" ]; then
    echo "Removing Nezha Agent service file..."
    rm /etc/systemd/system/nezha-agent.service
    echo "Service file removed."
else
    echo "No Nezha Agent service file found in /etc/systemd/system."
fi

# 重新加载 systemd 配置
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Nezha Agent has been successfully removed."
