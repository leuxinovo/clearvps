#!/bin/bash

echo "🔧 开始安装 Nezha Agent..."

# 输入 Nezha 面板地址
read -p "请输入 Nezha 面板地址 (如 dashboard.example.com:8008): " NZ_SERVER

# 输入 UUID
read -p "请输入 UUID: " NZ_UUID

# 输入 Client Secret
read -p "请输入 Client Secret: " NZ_CLIENT_SECRET

# 输入是否启用 TLS
read -p "是否启用 TLS? (true/false): " NZ_TLS

# 下载原始 agent 安装脚本
curl -fsSL https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh
chmod +x agent.sh

# 执行带环境变量的安装脚本
echo "🚀 执行安装命令..."
env NZ_SERVER="$NZ_SERVER" NZ_UUID="$NZ_UUID" NZ_CLIENT_SECRET="$NZ_CLIENT_SECRET" NZ_TLS="$NZ_TLS" ./agent.sh
