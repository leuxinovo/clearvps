#!/bin/bash
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本

# 1️⃣ 输入域名
read -p "请输入要申请证书的域名（支持通配符，例如 *.example.com）： " DOMAIN

# 2️⃣ 输入邮箱
read -p "请输入 Cloudflare 注册邮箱： " CF_EMAIL

# 3️⃣ 输入全局 API Key
read -s -p "请输入 Cloudflare 全局 API Key： " CF_KEY
echo

# 4️⃣ 输入证书存放目录
read -p "请输入证书保存的目录（例如 /root/certs）： " CERT_PATH

# 创建保存目录
mkdir -p "$CERT_PATH"

# 设置环境变量
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 申请证书
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN"

# 安装证书到指定目录
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_PATH/$DOMAIN.key" \
--fullchain-file "$CERT_PATH/$DOMAIN.cer"

echo "证书申请完成！"
echo "私钥路径: $CERT_PATH/$DOMAIN.key"
echo "证书路径: $CERT_PATH/$DOMAIN.cer"
