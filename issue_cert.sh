#!/bin/bash
# ===================================================
# acme.sh 自动申请 / 删除 Cloudflare DNS 通配符证书脚本
# ===================================================

DEFAULT_CERT_PATH="/root/certs"

# 日志输出函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "脚本开始执行..."

# 0️⃣ 选择操作
echo "请选择操作："
echo " [1] 申请 / 更新证书（默认）"
echo " [2] 删除证书"
read -p "请输入选项 [1/2]: " ACTION
ACTION=${ACTION:-1}

# =========================
# 删除证书函数
# =========================
delete_cert() {
    log "进入证书删除模式"

    if [ ! -f ~/.acme.sh/acme.sh ]; then
        log "未检测到 acme.sh，无法删除证书"
        exit 1
    fi

    echo "--------------------------------------------------"
    log "当前 acme.sh 已存在的证书："
    ~/.acme.sh/acme.sh --list
    echo "--------------------------------------------------"

    read -p "请输入要删除的域名（如 example.com 或 *.example.com）: " DEL_DOMAIN
    if [ -z "$DEL_DOMAIN" ]; then
        log "域名不能为空"
        exit 1
    fi

    read -p "⚠️ 确认删除证书 [$DEL_DOMAIN]？此操作不可恢复 [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log "已取消删除操作"
        exit 0
    fi

    ~/.acme.sh/acme.sh --remove -d "$DEL_DOMAIN" || {
        log "acme.sh 证书删除失败"
        exit 1
    }

    rm -f "$CERT_PATH/$DEL_DOMAIN.key"
    rm -f "$CERT_PATH/$DEL_DOMAIN.cer"

    log "✅ 证书 [$DEL_DOMAIN] 已成功删除"
    exit 0
}

# 如果选择删除证书
if [ "$ACTION" = "2" ]; then
    read -p "请输入证书保存目录（默认: $DEFAULT_CERT_PATH）: " CERT_PATH
    CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}
    delete_cert
fi

# =========================
# 以下为申请证书流程
# =========================

# 1️⃣ 选择 CA
read -p "请选择 CA [1] ZeroSSL (默认) [2] Let's Encrypt]: " CA_CHOICE
if [ "$CA_CHOICE" == "2" ]; then
    CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    CA_SERVER="https://acme.zerossl.com/v2/DV90"
fi

# 2️⃣ 输入域名
read -p "请输入要申请证书的域名（*.example.com 表示通配符）: " DOMAIN
if [ -z "$DOMAIN" ]; then
    log "域名不能为空！"
    exit 1
fi
DOMAINS="$DOMAIN"

# 3️⃣ Cloudflare 邮箱
read -p "请输入 Cloudflare 注册邮箱: " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    log "邮箱不能为空！"
    exit 1
fi

# 4️⃣ Cloudflare API Key
read -s -p "请输入 Cloudflare 全局 API Key: " CF_KEY
echo
if [ -z "$CF_KEY" ]; then
    log "API Key 不能为空！"
    exit 1
fi

# 5️⃣ 证书保存目录
read -p "请输入证书保存目录（默认: $DEFAULT_CERT_PATH）: " CERT_PATH
CERT_PATH=${CERT_PATH:-$DEFAULT_CERT_PATH}
mkdir -p "$CERT_PATH"

export CF_Key="$CF_KEY"
export CF_Email="$CF_EMAIL"

# 6️⃣ 检查 acme.sh
if [ ! -f ~/.acme.sh/acme.sh ]; then
    log "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | bash || exit 1
    source ~/.bashrc 2>/dev/null || source ~/.profile 2>/dev/null
else
    log "acme.sh 已安装"
fi

# 7️⃣ 检查已有证书
if ~/.acme.sh/acme.sh --list | grep -q "$DOMAIN"; then
    log "检测到已有该域名证书"
    read -p "是否覆盖已有证书？[y/N]: " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        FORCE="--force"
    else
        log "已取消申请"
        exit 0
    fi
fi

# 8️⃣ cron
~/.acme.sh/acme.sh --install-cronjob >/dev/null 2>&1

# 9️⃣ 注册 ZeroSSL
if [ "$CA_SERVER" = "https://acme.zerossl.com/v2/DV90" ]; then
    ~/.acme.sh/acme.sh --register-account -m "$CF_EMAIL" --server $CA_SERVER
fi

# 🔟 申请证书
log "开始申请证书..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAINS" $FORCE --server $CA_SERVER || {
    log "证书申请失败"
    exit 1
}

# 1️⃣1️⃣ 安装证书
~/.acme.sh/acme.sh --install-cert -d "$DOMAINS" \
    --key-file "$CERT_PATH/$DOMAIN.key" \
    --fullchain-file "$CERT_PATH/$DOMAIN.cer" || exit 1

log "=================================================="
log "🎉 证书申请完成"
log "私钥: $CERT_PATH/$DOMAIN.key"
log "证书: $CERT_PATH/$DOMAIN.cer"
log "已启用自动续期"
log "=================================================="
