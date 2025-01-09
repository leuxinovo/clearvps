#!/bin/bash

# 欢迎信息
echo "=============================================="
echo " 欢迎使用 Leu SSH公钥一键导入脚本"
echo " 本脚本将从GitHub 获取指定用户的SSH公钥并配置到当前VPS"
echo "=============================================="

# 检查是否提供了 GitHub 用户名
if [ -z "$1" ]; then
    echo "用法: $0 <GitHub用户名>"
    exit 1
fi

GITHUB_USERNAME="$1"
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 创建 .ssh 目录（如果不存在）
if [ ! -d "$SSH_DIR" ]; then
    echo "创建 .ssh 目录"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# 从 GitHub 获取用户的 SSH 公钥
echo "从 GitHub 获取 SSH 公钥..."
GITHUB_KEYS_URL="https://github.com/$GITHUB_USERNAME.keys"
SSH_KEYS=$(curl -s "$GITHUB_KEYS_URL")

if [ -z "$SSH_KEYS" ]; then
    echo "未能获取到GitHub用户$GITHUB_USERNAME的SSH公钥"
    echo "请检查用户名是否正确 或确保该用户在GitHub上有SSH公钥"
    exit 2
fi

# 检查 SSH 公钥格式
if ! echo "$SSH_KEYS" | grep -q "^ssh-rsa"; then
    echo "获取的内容不是有效的SSH公钥"
    exit 3
fi

# 检查公钥是否已经存在于 authorized_keys 中
if grep -Fxq "$SSH_KEYS" "$AUTHORIZED_KEYS"; then
    echo "公钥已存在于$AUTHORIZED_KEYS中，无需重复添加"
    exit 4
fi

# 将 SSH 公钥写入 authorized_keys
echo "写入SSH公钥到$AUTHORIZED_KEYS"
echo "$SSH_KEYS" >> "$AUTHORIZED_KEYS"

# 确保 authorized_keys 的权限正确
chmod 600 "$AUTHORIZED_KEYS"

echo "=============================================="
echo "操作完成！GitHub用户$GITHUB_USERNAME的SSH公钥已成功添加到$AUTHORIZED_KEYS"
echo "=============================================="
