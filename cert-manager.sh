
#!/usr/bin/env bash
# acme.sh SSL 证书管理脚本
# 功能：申请、续期、删除、导出、自动续期
# 默认导出目录：/root/cert

set -uo pipefail
umask 077

ACME_HOME="/root/.acme.sh"
ACME="$ACME_HOME/acme.sh"
DEFAULT_CERT_DIR="/root/cert"
LOG_FILE="/var/log/cert-manager.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

pause() {
    echo
    read -r -p "按回车键继续..." _ || true
}

valid_domain() {
    local d="${1%.}"
    [[ ${#d} -le 253 ]] || return 1
    [[ "$d" =~ ^(\*\.)?([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

get_email() {
    local auto_email
    auto_email="admin@$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo example.com)"
    auto_email="${auto_email// /}"

    echo "默认邮箱：$auto_email"
    read -r -p "请输入邮箱（直接回车使用默认邮箱）：" EMAIL || true
    EMAIL="${EMAIL:-$auto_email}"

    if [[ ! "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        echo "邮箱格式不正确。"
        return 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "请使用 root 运行此脚本：sudo bash $0"
        exit 1
    fi
}

install_acme() {
    if [[ ! -x "$ACME" ]]; then
        echo "未找到 acme.sh，正在尝试安装..."

        if ! command -v curl >/dev/null 2>&1; then
            echo "缺少 curl，请先安装 curl。"
            return 1
        fi

        if ! command -v cron >/dev/null 2>&1 &&
           ! command -v crontab >/dev/null 2>&1; then
            echo "提示：系统可能没有安装 cron，自动续期任务需检查。"
        fi

        if ! curl -fsSL https://get.acme.sh | sh -s email=admin@example.com; then
            echo "acme.sh 安装失败。"
            return 1
        fi
    fi

    if [[ ! -x "$ACME" ]]; then
        echo "找不到可执行文件：$ACME"
        return 1
    fi

    # 默认使用 Let's Encrypt
    "$ACME" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true

    # 安装自动续期任务；如果系统不支持，会提示检查
    "$ACME" --install-cronjob >/dev/null 2>&1 || true
}

choose_cert_dir() {
    read -r -p "证书导出目录（回车默认 $DEFAULT_CERT_DIR）：" CERT_DIR || true
    CERT_DIR="${CERT_DIR:-$DEFAULT_CERT_DIR}"

    if [[ "$CERT_DIR" != /* ]]; then
        echo "请输入绝对路径，例如 /root/cert。"
        return 1
    fi

    if [[ "$CERT_DIR" == "/" ]]; then
        echo "不能将根目录 / 作为证书导出目录。"
        return 1
    fi

    mkdir -p "$CERT_DIR" || return 1
}

choose_domain() {
    read -r -p "请输入域名：" DOMAIN || true
    DOMAIN="${DOMAIN,,}"

    if ! valid_domain "$DOMAIN"; then
        echo "域名格式不正确：$DOMAIN"
        return 1
    fi
}

choose_validation() {
    echo
    echo "验证方式："
    echo "  1. Standalone（默认，需要 80 端口可访问）"
    echo "  2. Webroot（网站已运行时使用）"
    read -r -p "请选择 [1]：" VALIDATION || true
    VALIDATION="${VALIDATION:-1}"

    case "$VALIDATION" in
        1)
            ISSUE_ARGS=(--standalone)
            ;;
        2)
            read -r -p "请输入网站根目录，例如 /var/www/html：" WEBROOT || true
            if [[ -z "${WEBROOT:-}" || ! -d "$WEBROOT" ]]; then
                echo "网站根目录不存在，请检查路径。"
                return 1
            fi
            ISSUE_ARGS=(--webroot "$WEBROOT")
            ;;
        *)
            echo "无效选项。"
            return 1
            ;;
    esac
}

choose_ip_mode() {
    echo
    echo "监听地址："
    echo "  1. IPv4"
    echo "  2. IPv6"
    echo "  3. IPv4 + IPv6（默认）"
    read -r -p "请选择 [3]：" IP_MODE || true
    IP_MODE="${IP_MODE:-3}"

    case "$IP_MODE" in
        1) ISSUE_ARGS+=(--listen-v4) ;;
        2) ISSUE_ARGS+=(--listen-v6) ;;
        3) ISSUE_ARGS+=(--listen-v4 --listen-v6) ;;
        *)
            echo "无效选项。"
            return 1
            ;;
    esac
}

export_cert() {
    local domain="$1"
    local dest="$2"
    local out="$dest/$domain"

    mkdir -p "$out" || return 1

    if ! "$ACME" --install-cert -d "$domain" \
        --key-file "$out/privkey.pem" \
        --fullchain-file "$out/fullchain.pem" \
        --cert-file "$out/cert.pem" \
        --ca-file "$out/chain.pem"; then
        echo "导出失败，请检查 acme.sh 日志。"
        return 1
    fi

    chmod 600 "$out/privkey.pem" 2>/dev/null || true
    chmod 644 "$out/fullchain.pem" "$out/cert.pem" "$out/chain.pem" 2>/dev/null || true

    echo "证书已导出到：$out"
    echo "私钥：$out/privkey.pem"
    echo "完整证书链：$out/fullchain.pem"
}

issue_cert() {
    install_acme || return 1
    choose_domain || return 1
    get_email || return 1
    choose_cert_dir || return 1
    choose_validation || return 1
    choose_ip_mode || return 1

    echo
    echo "即将申请：$DOMAIN"
    echo "验证方式：${VALIDATION}"
    echo "导出目录：$CERT_DIR/$DOMAIN"
    read -r -p "确认申请？[y/N]：" confirm || true
    [[ "$confirm" =~ ^[Yy]$ ]] || {
        echo "已取消。"
        return 0
    }

    # 如果该域名已经有记录，优先尝试续期，不直接覆盖密钥
    if "$ACME" --list 2>/dev/null | grep -Fq "$DOMAIN"; then
        echo "检测到 acme.sh 中可能已有该域名的证书记录。"
        read -r -p "先尝试续期？[Y/n]：" renew_first || true
        renew_first="${renew_first:-Y}"

        if [[ "$renew_first" =~ ^[Yy]$ ]]; then
            if "$ACME" --renew -d "$DOMAIN"; then
                export_cert "$DOMAIN" "$CERT_DIR"
                return $?
            fi
            echo "续期失败。"
        fi
    fi

    # 使用默认验证方式申请
    if "$ACME" --issue -d "$DOMAIN" \
        --server letsencrypt \
        --accountemail "$EMAIL" \
        "${ISSUE_ARGS[@]}"; then
        export_cert "$DOMAIN" "$CERT_DIR"
        return $?
    fi

    echo
    echo "申请失败。可能是旧密钥残留、DNS 解析、端口或验证问题。"
    echo "请先确认域名解析正确，并且验证所需端口可以从公网访问。"
    echo "不要反复强制申请，以免触发 CA 频率限制。"
    read -r -p "是否确认要强制重新申请？[y/N]：" force_retry || true

    if [[ "$force_retry" =~ ^[Yy]$ ]]; then
        if "$ACME" --issue -d "$DOMAIN" \
            --server letsencrypt \
            --accountemail "$EMAIL" \
            "${ISSUE_ARGS[@]}" \
            --force; then
            export_cert "$DOMAIN" "$CERT_DIR"
            return $?
        fi
        echo "强制申请仍然失败，请查看日志：$ACME_HOME"
        return 1
    fi

    echo "已取消强制重试。"
    return 1
}

renew_cert() {
    install_acme || return 1
    choose_domain || return 1

    echo "正在尝试续期：$DOMAIN"
    if "$ACME" --renew -d "$DOMAIN"; then
        echo "续期成功。"
        read -r -p "是否重新导出证书？[Y/n]：" do_export || true
        do_export="${do_export:-Y}"

        if [[ "$do_export" =~ ^[Yy]$ ]]; then
            choose_cert_dir || return 1
            export_cert "$DOMAIN" "$CERT_DIR"
        fi
    else
        echo "续期失败。请确认该域名已经由 acme.sh 成功签发过证书。"
        return 1
    fi
}

delete_cert() {
    install_acme || return 1
    choose_domain || return 1

    echo
    echo "警告：即将删除域名 $DOMAIN 的 acme.sh 证书记录及其管理目录。"
    echo "这可能会删除该域名在 acme.sh 下保存的私钥、证书和配置。"
    echo "如果此域名仍在使用，请先备份证书和私钥。"
    read -r -p "确定删除请输入 y：" confirm || true

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消删除。"
        return 0
    fi

    # 从 acme.sh 续期管理列表中移除
    "$ACME" --remove -d "$DOMAIN" >/dev/null 2>&1 || true

    # 清理 acme.sh 保存的域名目录（含普通和 ECC 目录）
    # DOMAIN 已通过域名格式验证，不允许任意路径输入
    local d
    for d in "$ACME_HOME/$DOMAIN" "$ACME_HOME/${DOMAIN}_ecc"; do
        if [[ -d "$d" ]]; then
            rm -rf -- "$d"
        fi
    done

    # 清理默认导出目录中的文件
    if [[ -d "$DEFAULT_CERT_DIR/$DOMAIN" ]]; then
        rm -rf -- "$DEFAULT_CERT_DIR/$DOMAIN"
    fi

    echo "已清理 acme.sh 记录及默认导出目录（如果存在）。"
    echo "注意：自定义导出目录中的副本不会自动删除。"
    echo "如果之后重新申请仍提示密钥存在，请先查看："
    echo "  $ACME_HOME/$DOMAIN"
    echo "  $ACME_HOME/${DOMAIN}_ecc"
}

list_certs() {
    install_acme || return 1
    "$ACME" --list
}

show_menu() {
    clear 2>/dev/null || true
    echo "=================================="
    echo "       acme.sh 证书管理工具"
    echo "=================================="
    echo "1. 申请证书"
    echo "2. 续期证书"
    echo "3. 删除证书"
    echo "4. 导出证书"
    echo "5. 查看证书列表"
    echo "6. 检查自动续期任务"
    echo "0. 退出"
    echo "=================================="
}

check_renewal() {
    echo "acme.sh 自动续期任务检查："
    if command -v crontab >/dev/null 2>&1; then
        crontab -l 2>/dev/null | grep -E 'acme\.sh.*--cron' || {
            echo "当前用户的 crontab 中未找到 acme.sh 续期任务。"
            echo "尝试安装续期任务..."
            "$ACME" --install-cronjob
        }
    else
        echo "系统未找到 crontab 命令，请检查 cron 服务是否安装。"
    fi
}

main() {
    check_root
    install_acme || {
        echo "acme.sh 初始化失败。"
        exit 1
    }

    while true; do
        show_menu
        read -r -p "请选择操作 [0-6]：" choice || choice="0"

        case "$choice" in
            1) issue_cert; pause ;;
            2) renew_cert; pause ;;
            3) delete_cert; pause ;;
            4)
                install_acme && choose_domain && choose_cert_dir &&
                    export_cert "$DOMAIN" "$CERT_DIR"
                pause
                ;;
            5) list_certs; pause ;;
            6) check_renewal; pause ;;
            0) echo "退出。"; exit 0 ;;
            *) echo "无效选项，请输入 0-6。"; pause ;;
        esac
    done
}

main "$@"
