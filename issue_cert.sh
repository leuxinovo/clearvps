#!/bin/bash
# ===================================================
# acme.sh 自动申请 Cloudflare DNS 通配符证书脚本
# ===================================================

DEFAULT_CERT_PATH="/root/certs"

# 日志输出函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "脚本开始执行..."

# 1️⃣ 选择 CA
read -p "请选择 CA [1] ZeroSSL (默认) [2] Let's Encrypt]: " CA_CHOICE
if [ "$CA_CHOICE" == "2" ]; then
    CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    CA_SERVER="https://acme.zerossl.com/v2/DV90"
fi

# 2️⃣ 输入域名
read -p "请输入要申请证书的域名（输入 *.example.com 表示通配符证书）: " DOMAIN
if [ -z "$DOMAIN" ]; then
    log "域名不能为空！"
    exit 1
fi

# 处理域名逻辑：只有输入 * 开头才当作通配符
DOMAINS="$DOMAIN"

# 3️⃣ 输入 Cloudflare 邮箱
read -p "请输入 Cloudflare 注册邮箱: " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    log "邮箱不能为空！"
    exit 1
fi

# 4️⃣ 输入 Cloudflare 全局 API Key
read -s -p "请输入 Cloudflare 全局 API Key: " CF_KEY
echo
if [ -z "$CF_KEY" ]; then
    log "API Key 不能为空！"
    exit 1
fi

# 5️⃣ 输入证书保存目录
read -p "请输入证书保存目录（默认: $DEFAULT_CERT_PATH）: " CERT_PATH
CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}
mkdir -p "$CERT_PATH"

# 设置 Cloudflare API
export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 6️⃣ 检查 acme.sh 是否安装并且没有损坏
if [ ! -d ~/.acme.sh ]; then
    log "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | bash || { log "acme.sh 安装失败"; exit 1; }
    source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
elif [ ! -f ~/.acme.sh/acme.sh ]; then
    log "acme.sh 配置文件丢失，正在重新安装..."
    curl https://get.acme.sh | bash || { log "acme.sh 安装失败"; exit 1; }
    source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
else
    log "acme.sh 已安装，跳过安装步骤。"
fi

# 7️⃣ 检查已有证书
if ~/.acme.sh/acme.sh --list | grep -q "$DOMAIN"; then
    log "检测到已有该域名证书"
    read -p "是否覆盖已有证书？[y/N]: " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        FORCE="--force"
    else
        log "跳过证书申请"
        exit 0
    fi
fi

# 8️⃣ 安装 cron
if ! command -v crontab >/dev/null 2>&1; then
    log "检测到系统未安装 cron，正在尝试安装..."
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y cron
        systemctl enable cron && systemctl start cron
    elif command -v yum >/dev/null 2>&1; then
        yum install -y cronie
        systemctl enable crond && systemctl start crond
    else
        log "未检测到 apt 或 yum，请手动安装 cron"
    fi
fi

~/.acme.sh/acme.sh --install-cronjob >/dev/null 2>&1

# 9️⃣ 注册账户（ZeroSSL 需要邮箱）
if [ "$CA_SERVER" = "https://acme.zerossl.com/v2/DV90" ]; then
    ~/.acme.sh/acme.sh --register-account -m "$CF_EMAIL" --server $CA_SERVER
fi

# 1️⃣0️⃣ 申请证书
log "开始申请证书..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAINS" $FORCE --server $CA_SERVER || {
    log "证书申请失败，请检查 API Key、域名解析或网络"
    exit 1
}

# 1️⃣1️⃣ 安装证书
~/.acme.sh/acme.sh --install-cert -d "$DOMAINS" \
    --key-file "$CERT_PATH/$DOMAIN.key" \
    --fullchain-file "$CERT_PATH/$DOMAIN.cer" || {
    log "证书安装失败，请检查目录权限"
    exit 1
}

log "=================================================="
log "证书申请完成！"
log "私钥路径: $CERT_PATH/$DOMAIN.key"
log "证书路径: $CERT_PATH/$DOMAIN.cer"
log "证书将自动续期（请确保 cron 已正常运行）"
log "=================================================="
