#!/bin/bash
# ===================================================
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本（兼容 dash/sh）
# 特性：
# - IPv6 VPS 支持
# - Warp 提示
# - Cloudflare DNS-01 验证
# - 通配符域名
# - 默认下载路径
# - ZeroSSL / Let's Encrypt CA 可选
# - 自动安装 cron 并确保证书自动续期
# - acme.sh 安装兼容 dash/sh
# ===================================================

# 默认证书保存目录
DEFAULT_CERT_PATH="/root/certs"

# 1️⃣ 选择 CA: ZeroSSL 或 Let's Encrypt
read -p "请选择 CA [1] ZeroSSL (默认) [2] Let's Encrypt: " CA_CHOICE
if [ "$CA_CHOICE" == "2" ]; then
    CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    CA_SERVER="https://acme.zerossl.com/v2/DV90"
fi

# 2️⃣ 检测 Warp 是否开启（通过 IPv6 外网访问）
if command -v curl >/dev/null 2>&1; then
    WARP_STATUS=$(curl -6 -s https://ifconfig.co | grep -q ':' && echo "enabled" || echo "disabled")
    if [ "$WARP_STATUS" == "enabled" ]; then
        echo "检测到 VPS 可能开启了 Warp，强烈建议使用 DNS-01 模式申请证书"
    fi
fi

# 3️⃣ 输入域名
read -p "请输入要申请证书的域名（支持通配符，例如 *.example.com）： " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空！"
    exit 1
fi

# 4️⃣ 输入 Cloudflare 邮箱
read -p "请输入 Cloudflare 注册邮箱： " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 1
fi

# 5️⃣ 输入 Cloudflare 全局 API Key
read -s -p "请输入 Cloudflare 全局 API Key： " CF_KEY
echo
if [ -z "$CF_KEY" ]; then
    echo "API Key 不能为空！"
    exit 1
fi

# 6️⃣ 输入证书保存目录，回车使用默认路径
read -p "请输入证书保存的目录（默认: $DEFAULT_CERT_PATH）： " CERT_PATH
CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}

# 创建保存目录
mkdir -p "$CERT_PATH"

# 设置 Cloudflare API 环境变量
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 7️⃣ 检查 acme.sh 是否安装
if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | bash || { echo "acme.sh 安装失败，请检查网络或权限"; exit 1; }
    # 更新环境变量
    if [ -f ~/.bashrc ]; then
        source ~/.bashrc
    elif [ -f ~/.profile ]; then
        source ~/.profile
    fi
fi

# 8️⃣ 安装 cron 并确保续期
if ! command -v crontab >/dev/null 2>&1; then
    echo "检测到系统未安装 cron，正在尝试安装..."
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y cron
        systemctl enable cron && systemctl start cron
    elif command -v yum >/dev/null 2>&1; then
        yum install -y cronie
        systemctl enable crond && systemctl start crond
    else
        echo "未检测到 apt 或 yum，请手动安装 cron，否则证书无法自动续期"
    fi
fi

# 确保 acme.sh cron 已安装
~/.acme.sh/acme.sh --install-cronjob || echo "警告：acme.sh 自动续期任务可能未成功安装"

# 9️⃣ 注册 ZeroSSL 账户（如果选择 ZeroSSL）
if [ "$CA_SERVER" = "https://acme.zerossl.com/v2/DV90" ]; then
    echo "注册 ZeroSSL 账户..."
    ~/.acme.sh/acme.sh --register-account -m "$CF_EMAIL" --server $CA_SERVER || {
        echo "ZeroSSL 账户注册失败，请检查邮箱或网络"
        exit 1
    }
fi

# 10️⃣ 申请证书（DNS-01 验证，自动支持 IPv6）
echo "开始申请证书..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.${DOMAIN#*.}" --server $CA_SERVER || {
    echo "证书申请失败，请检查 API Key、域名解析或网络"
    exit 1
}

# 11️⃣ 安装证书到指定目录
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_PATH/$DOMAIN.key" \
--fullchain-file "$CERT_PATH/$DOMAIN.cer" || {
    echo "证书安装失败，请检查目录权限"
    exit 1
}

echo "=================================================="
echo "证书申请完成！"
echo "私钥路径: $CERT_PATH/$DOMAIN.key"
echo "证书路径: $CERT_PATH/$DOMAIN.cer"
echo "证书将自动续期（请确保 cron 已正常运行）"
echo "=================================================="
