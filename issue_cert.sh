#!/bin/bash
# ===================================================
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本
# ===================================================

DEFAULT_CERT_PATH="/root/certs"

# 1️⃣ 选择 CA
read -p "请选择 CA [1] ZeroSSL (默认) [2] Let's Encrypt: " CA_CHOICE
if [ "$CA_CHOICE" == "2" ]; then
    CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    CA_SERVER="https://acme.zerossl.com/v2/DV90"
fi

# 2️⃣ 输入域名
read -p "请输入要申请证书的域名（支持通配符，例如 *.example.com）： " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空！"
    exit 1
fi

# 处理通配符逻辑
if [[ "$DOMAIN" == \** ]]; then
    DOMAINS="$DOMAIN"
else
    DOMAINS="*.$DOMAIN"
fi

# 3️⃣ 输入 Cloudflare 邮箱
read -p "请输入 Cloudflare 注册邮箱： " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 1
fi

# 4️⃣ 输入 Cloudflare 全局 API Key
read -s -p "请输入 Cloudflare 全局 API Key： " CF_KEY
echo
if [ -z "$CF_KEY" ]; then
    echo "API Key 不能为空！"
    exit 1
fi

# 5️⃣ 输入证书保存目录
read -p "请输入证书保存目录（默认: $DEFAULT_CERT_PATH）： " CERT_PATH
CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}
mkdir -p "$CERT_PATH"

# 设置 Cloudflare API
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 6️⃣ 检查 acme.sh
if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | bash || { echo "acme.sh 安装失败"; exit 1; }
    source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
fi

# 7️⃣ 检查已有证书
if ~/.acme.sh/acme.sh --list | grep -q "$DOMAIN"; then
    echo "检测到已有该域名证书"
    read -p "是否覆盖已有证书？[y/N]: " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        FORCE="--force"
    else
        echo "跳过证书申请"
        exit 0
    fi
fi

# 8️⃣ 安装 cron
if ! command -v crontab >/dev/null 2>&1; then
    echo "检测到系统未安装 cron，正在尝试安装..."
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y cron
        systemctl enable cron && systemctl start cron
    elif command -v yum >/dev/null 2>&1; then
        yum install -y cronie
        systemctl enable crond && systemctl start crond
    else
        echo "未检测到 apt 或 yum，请手动安装 cron"
    fi
fi

~/.acme.sh/acme.sh --install-cronjob >/dev/null 2>&1

# 9️⃣ 注册账户（ZeroSSL 需要邮箱）
if [ "$CA_SERVER" = "https://acme.zerossl.com/v2/DV90" ]; then
    ~/.acme.sh/acme.sh --register-account -m "$CF_EMAIL" --server $CA_SERVER
fi

# 10️⃣ 申请证书
echo "开始申请证书..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAINS" $FORCE --server $CA_SERVER || {
    echo "证书申请失败，请检查 API Key、域名解析或网络"
    exit 1
}

# 11️⃣ 安装证书
~/.acme.sh/acme.sh --install-cert -d "$DOMAINS" \
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
