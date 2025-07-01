#!/bin/bash

BASE_DIR="/root/domain"
PID_FILE="$BASE_DIR/scan_domains.pid"
STATUS_FILE="$BASE_DIR/scan_status.log"
ERROR_LOG="$BASE_DIR/scan_error.log"
OUTPUT_FILE=""

ensure_dir() {
  [[ -d "$BASE_DIR" ]] || mkdir -p "$BASE_DIR"
}

check_whois() {
  if ! command -v whois >/dev/null 2>&1; then
    echo "错误：系统未安装 whois，请先安装（Debian/Ubuntu: apt install whois）" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if [[ -n "$PID" ]] && ps -p "$PID" > /dev/null 2>&1; then
      kill "$PID" && echo "停止后台扫描进程（PID: $PID）"
    else
      echo "扫描进程未运行"
    fi
    rm -f "$PID_FILE"
  else
    echo "无扫描进程PID文件，无需停止"
  fi

  rm -f "$STATUS_FILE" "$ERROR_LOG"
  echo "卸载完成：状态文件和日志已删除，域名文件保留"
  exit 0
}

scan_domain() {
  local prefix=$1
  local depth=$2
  local tld=$3
  local chars=("${!4}")
  local length=$5

  if (( depth == length )); then
    local domain="${prefix}.${tld}"

    local result
    result=$(whois "$domain" 2>>"$ERROR_LOG")

    if echo "$result" | grep -iqE "status: free|status: available|no entries found|NOT FOUND|No match|No Data Found|Status: free"; then
      echo "$domain 未注册" >> "$STATUS_FILE"
      echo "$domain" >> "$OUTPUT_FILE"
    else
      echo "$domain 已注册" >> "$STATUS_FILE"
    fi
    sync "$STATUS_FILE" "$OUTPUT_FILE"
    sleep 1
    return
  fi

  for c in "${chars[@]}"; do
    scan_domain "${prefix}${c}" $((depth + 1)) "$tld" chars[@] "$length"
  done
}

run_scan_bg() {
  local tld="$1"
  local char_type="$2"
  local length="$3"

  ensure_dir
  check_whois

  OUTPUT_FILE="$BASE_DIR/domain_${tld}.txt"
  > "$OUTPUT_FILE"
  > "$STATUS_FILE"
  > "$ERROR_LOG"

  local chars=()
  case "$char_type" in
    1) chars=( {0..9} ) ;;
    2) chars=( {a..z} ) ;;
    3) chars=( {0..9} {a..z} ) ;;
    *) echo "字符类型错误，退出" >&2; exit 1 ;;
  esac

  scan_domain "" 0 "$tld" chars[@] "$length"

  echo "扫描完成！" >> "$STATUS_FILE"
  rm -f "$PID_FILE"
  exit 0
}

start_scan() {
  ensure_dir
  check_whois

  read -rp "请输入要扫描的域名后缀（例如 de/com/net）: " tld
  OUTPUT_FILE="$BASE_DIR/domain_${tld}.txt"

  while true; do
    echo "请选择扫描字符类型："
    echo "1. 纯数字"
    echo "2. 纯字母"
    echo "3. 数字+字母混合"
    read -rp "选择（1/2/3）: " char_type
    [[ "$char_type" =~ ^[123]$ ]] && break
    echo "输入错误，请输入数字1、2或3"
  done

  while true; do
    read -rp "请输入要扫描的位数（正整数，例如 3）: " length
    if [[ "$length" =~ ^[1-9][0-9]*$ ]]; then
      break
    fi
    echo "输入无效，请输入正整数（不能以0开头）"
  done

  cd "$BASE_DIR" || { echo "切换目录失败，退出"; exit 1; }

  nohup bash "$0" run_bg "$tld" "$char_type" "$length" > /dev/null 2>>"$ERROR_LOG" &
  echo $! > "$PID_FILE"

  echo "后台扫描已启动，结果保存到 $OUTPUT_FILE"
  echo "停止扫描：kill \$(cat $PID_FILE)"
  echo "卸载脚本：运行本脚本选择 2"
}

view_status() {
  ensure_dir

  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "扫描状态文件不存在，暂无扫描任务"
    return
  fi

  echo "实时查看扫描状态，按 0 键退出"

  tail -n 20 -f "$STATUS_FILE" &
  TAIL_PID=$!

  while true; do
    read -rsn1 key 2>/dev/null || true
    if [[ "$key" == "0" ]]; then
      kill "$TAIL_PID" 2>/dev/null
      wait "$TAIL_PID" 2>/dev/null
      echo -e "\n退出查看"
      break
    fi
  done
}

if [[ "$1" == "run_bg" ]]; then
  run_scan_bg "$2" "$3" "$4"
  exit 0
fi

while true; do
  echo ""
  echo "请选择操作："
  echo "1. 安装并开始扫描（后台运行）"
  echo "2. 卸载脚本（停止扫描+删除状态文件和日志，保留域名文件）"
  echo "3. 查看扫描状态（实时）"
  echo "0. 退出"
  read -rp "请输入数字选择: " choice

  if [[ ! "$choice" =~ ^[0-3]$ ]]; then
    echo "输入错误，请输入 0-3 的数字"
    continue
  fi

  case "$choice" in
    1) start_scan ;;
    2) cleanup ;;
    3) view_status ;;
    0) echo "退出"; exit 0 ;;
  esac
done
