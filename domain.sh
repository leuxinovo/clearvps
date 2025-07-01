#!/bin/bash

BASE_DIR="/root/domain"
pid_file="$BASE_DIR/scan_domains.pid"
status_file="$BASE_DIR/scan_status.log"
error_log="$BASE_DIR/scan_error.log"
output_file=""

ensure_dir() {
  [[ -d "$BASE_DIR" ]] || mkdir -p "$BASE_DIR"
}

check_whois() {
  if ! command -v whois >/dev/null 2>&1; then
    echo "错误：系统未安装 whois，请先安装后重试。Debian/Ubuntu: apt install whois" >&2
    exit 1
  fi
}

cleanup() {
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if [[ -n "$pid" ]] && ps -p "$pid" > /dev/null 2>&1; then
      kill "$pid" && echo "已停止后台扫描进程（PID: $pid）"
    else
      echo "扫描进程未运行"
    fi
    rm -f "$pid_file"
  else
    echo "未发现扫描进程PID文件，无需停止扫描"
  fi

  rm -f "$status_file" "$error_log"
  echo "卸载完成，状态文件和日志已删除，域名文件保留"
  exit 0
}

run_scan_bg() {
  tld="$1"
  char_type="$2"
  length="$3"

  ensure_dir
  check_whois

  output_file="$BASE_DIR/domain_${tld}.txt"
  status_file="$BASE_DIR/scan_status.log"
  error_log="$BASE_DIR/scan_error.log"

  chars=()
  if [[ "$char_type" == "1" ]]; then
    chars=( {0..9} )
  elif [[ "$char_type" == "2" ]]; then
    chars=( {a..z} )
  elif [[ "$char_type" == "3" ]]; then
    chars=( {0..9} {a..z} )
  else
    echo "无效字符类型，退出" >&2
    exit 1
  fi

  > "$status_file"
  > "$error_log"

  scan_domain() {
    local prefix=$1
    local depth=$2

    if [[ $depth -eq $length ]]; then
      local domain="${prefix}.${tld}"

      result=$(whois "$domain" 2>>"$error_log")

      if echo "$result" | grep -iqE "status: free|status: available|no entries found|NOT FOUND|No match|No Data Found|Status: free"; then
        echo "$domain 未注册" >> "$status_file"
        echo "$domain" >> "$output_file"
      else
        echo "$domain 已注册" >> "$status_file"
      fi

      # 立即刷新输出
      sync "$status_file" "$output_file"

      sleep 1
      return
    fi

    for c in "${chars[@]}"; do
      scan_domain "${prefix}${c}" $((depth + 1))
    done
  }

  scan_domain "" 0
  echo "扫描完成！" >> "$status_file"
  rm -f "$pid_file"
  exit 0
}

start_scan() {
  ensure_dir
  check_whois

  read -rp "请输入要扫描的域名后缀（例如 de/com/net）: " tld

  output_file="$BASE_DIR/domain_${tld}.txt"

  while true; do
    echo "请选择扫描字符类型："
    echo "1. 纯数字"
    echo "2. 纯字母"
    echo "3. 数字+字母混合"
    read -rp "选择（1/2/3）: " char_type
    if [[ "$char_type" =~ ^[123]$ ]]; then
      break
    else
      echo "输入错误，请输入数字1、2或3"
    fi
  done

  while true; do
    read -rp "请输入要扫描的位数（正整数，例如 3）: " length
    if [[ "$length" =~ ^[1-9][0-9]*$ ]]; then
      break
    else
      echo "输入无效！请输入大于0的整数，且不能有小数点或前导零。"
    fi
  done

  cd "$BASE_DIR" || { echo "切换目录失败，退出"; exit 1; }

  nohup bash "$0" run_bg "$tld" "$char_type" "$length" > /dev/null 2>>"$error_log" &
  echo $! > "$pid_file"

  echo "后台扫描已启动，结果保存到 $output_file"
  echo "停止扫描：kill \$(cat $pid_file)"
  echo "卸载脚本：运行本脚本选择 2"
}

view_status() {
  ensure_dir

  if [[ ! -f "$status_file" ]]; then
    echo "扫描状态文件不存在，暂无扫描任务"
    return
  fi

  echo "实时查看扫描状态，按 0 键退出"

  tail -n 20 -f "$status_file" &
  tail_pid=$!

  while true; do
    read -rsn1 key 2>/dev/null || true
    if [[ "$key" == "0" ]]; then
      kill "$tail_pid" 2>/dev/null
      wait "$tail_pid" 2>/dev/null
      echo -e "\n退出查看"
      break
    fi
  done
}

if [[ "$1" == "run_bg" ]]; then
  run_scan_bg "$2" "$3" "$4"
fi

while true; do
  echo ""
  echo "请选择操作："
  echo "1. 安装并开始扫描（后台运行）"
  echo "2. 卸载脚本（停止扫描+删除状态日志，不删除域名文件）"
  echo "3. 查看扫描状态（实时）"
  echo "0. 退出"

  read -rp "请输入数字选择: " choice

  if [[ "$choice" =~ ^[0-3]$ ]]; then
    case "$choice" in
      1) start_scan ;;
      2) cleanup ;;
      3) view_status ;;
      0) echo "退出"; exit 0 ;;
    esac
  else
    echo "输入错误，请输入数字 0-3"
  fi
done
