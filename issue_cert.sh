#!/bin/bash
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本
# 支持回车使用默认下载路径

# 默认证书保存目录
DEFAULT_CERT_PATH="/root/certs"

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

# 设置环境变量
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 检查 acme.sh 是否安装
if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | sh
    source ~/.bashrc
fi

# 申请证书
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN"

# 安装证书到指定目录
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_PATH/$DOMAIN.key" \
--fullchain-file "$CERT_PATH/$DOMAIN.cer"

echo "证书申请完成！"
echo "私钥路径: $CERT_PATH/$DOMAIN.key"
echo "证书路径: $CERT_PATH/$DOMAIN.cer"
