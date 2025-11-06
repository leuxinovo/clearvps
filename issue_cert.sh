#!/bin/bash
# ===================================================
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本
# 支持 IPv6 VPS、Warp 提示、默认下载路径、错误提示
# ===================================================

# 默认证书保存目录
DEFAULT_CERT_PATH="/root/certs"

# 选择 CA: ZeroSSL 或 Let's Encrypt
read -p "请选择 CA [1] ZeroSSL (默认) [2] Let's Encrypt: " CA_CHOICE
if [ "$CA_CHOICE" == "2" ]; then
    CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    CA_SERVER="https://acme.zerossl.com/v2/DV90"
fi

# 检测 Warp 是否开启（通过 IPv6 外网访问）
WARP_STATUS=$(curl -6 -s https://ifconfig.co | grep -q ':' && echo "enabled" || echo "disabled")
if [ "$WARP_STATUS" == "enabled" ]; then
    echo "检测到 VPS 可能开启了 Warp，强烈建议使用 DNS-01 模式申请证书"
fi

# 1️⃣ 输入域名
read -p "请输入要申请证书的域名（支持通配符，例如 *.example.com）： " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空！"
    exit 1
fi

# 2️⃣ 输入 Cloudflare 邮箱
read -p "请输入 Cloudflare 注册邮箱： " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 1
fi

# 3️⃣ 输入 Cloudflare 全局 API Key
read -s -p "请输入 Cloudflare 全局 API Key： " CF_KEY
echo
if [ -z "$CF_KEY" ]; then
    echo "API Key 不能为空！"
    exit 1
fi

# 4️⃣ 输入证书保存目录，回车使用默认路径
read -p "请输入证书保存的目录（默认: $DEFAULT_CERT_PATH）： " CERT_PATH
CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}

# 创建保存目录
mkdir -p "$CERT_PATH"

# 设置 Cloudflare API 环境变量
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 检查 acme.sh 是否安装
if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | sh --force || { echo "acme.sh 安装失败，请检查网络或权限"; exit 1; }
    source ~/.bashrc
fi

# 注册账户（ZeroSSL 必须）
if [ "$CA_SERVER" == "https://acme.zerossl.com/v2/DV90" ]; then
    echo "注册 ZeroSSL 账户..."
    ~/.acme.sh/acme.sh --register-account -m "$CF_EMAIL" --server $CA_SERVER || {
        echo "ZeroSSL 账户注册失败，请检查邮箱或网络"
        exit 1
    }
fi

# 申请证书（DNS-01 验证，自动支持 IPv6）
echo "开始申请证书..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.${DOMAIN#*.}" --server $CA_SERVER || {
    echo "证书申请失败，请检查 API Key、域名解析或网络"
    exit 1
}

# 安装证书到指定目录
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
echo "=================================================="
