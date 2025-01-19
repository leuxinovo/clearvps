#!/bin/bash
# 颜色代码
blue="\033[94m"
reset="\033[0m"

# 输出内容
echo -e "${blue}欢迎使用Leu SSH公钥一键导入脚本${reset}"
echo -e "${blue}本脚本将从GitHub 获取指定用户的SSH公钥并配置到当前VPS${reset}"
echo -e "${blue}------------------------------------------------${reset}"

# 检查是否提供了 -g 参数
while getopts ":g:" opt; do
    case $opt in
        g)
            GITHUB_USERNAME="$OPTARG"
            ;;
        \?)
            echo "无效的选项: -$OPTARG"
            exit 1
            ;;
        :)
            echo "选项 -$OPTARG 需要一个参数"
            exit 1
            ;;
    esac
done

if [ -z "$GITHUB_USERNAME" ]; then
    echo "用法错误：请使用 -g 选项指定 GitHub 用户名"
    exit 1
fi

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

# 检查 GitHub 公钥是否为空
if [ -z "$SSH_KEYS" ]; then
    echo "错误：未能获取到 GitHub $GITHUB_USERNAME的 SSH 公钥"
    echo "请检查GitHub用户名是否错误或GitHub是否导入公钥"
    exit 2
fi

# 检查公钥是否已经存在于 authorized_keys 中
if grep -Fxq "$SSH_KEYS" "$AUTHORIZED_KEYS" 2>/dev/null; then
    echo "公钥已存在于 $AUTHORIZED_KEYS 中，无需重复添加"
    exit 0
fi

# 将 SSH 公钥写入 authorized_keys
echo "写入 SSH 公钥到 $AUTHORIZED_KEYS"
echo "$SSH_KEYS" >> "$AUTHORIZED_KEYS"

# 确保 authorized_keys 的权限正确
chmod 600 "$AUTHORIZED_KEYS"

echo "操作完成！GitHub 用户 $GITHUB_USERNAME 的 SSH 公钥已成功添加到 $AUTHORIZED_KEYS"
echo "------------------------------------------------"
