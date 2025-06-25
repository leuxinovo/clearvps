#!/bin/bash

echo "🔧 安装 Nezha Agent 开始..."

# 获取输入
read -p "请输入 Nezha 面板地址 (如 dashboard.example.com:8008): " NZ_SERVER
read -p "请输入 UUID: " NZ_UUID
read -p "是否启用 TLS? (true/false): " NZ_TLS

# 可选的 Client Secret（根据需要可取消注释）
# read -p "请输入 Client Secret（可选，默认留空）: " NZ_CLIENT_SECRET

# 默认使用固定 Client Secret，如果需要交互也可以修改
NZ_CLIENT_SECRET="EXAMPLE"

# 下载官方 agent 安装脚本
curl -fsSL https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh
chmod +x agent.sh

# 运行安装脚本
echo "🚀 开始安装 Nezha Agent..."
env NZ_SERVER="$NZ_SERVER" NZ_TLS="$NZ_TLS" NZ_CLIENT_SECRET="$NZ_CLIENT_SECRET" NZ_UUID="$NZ_UUID" ./agent.sh
