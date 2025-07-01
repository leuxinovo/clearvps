#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
output_file="$BASE_DIR/domain.txt"
status_file="$BASE_DIR/scan_status.log"
pid_file="$BASE_DIR/scan_domains.pid"
error_log="$BASE_DIR/scan_error.log"

function check_whois() {
  if ! command -v whois >/dev/null 2>&1; then
    echo "错误：系统未安装 whois，请先安装后重试。Debian/Ubuntu: apt install whois" >&2
    exit 1
  fi
}

function cleanup() {
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if ps -p "$pid" > /dev/null 2>&1; then
      kill "$pid" && echo "已停止后台扫描进程（PID: $pid）"
    fi
    rm -f "$pid_file"
  fi
  rm -f "$output_file" "$status_file" "$error_log"
  echo "卸载完成，已删除 $output_file $status_file $error_log 和 $pid_file"
  exit 0
}

function run_scan_bg() {
  tld="$1"
  char_type="$2"
  length="$3"

  check_whois

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

  > "$output_file"
  > "$status_file"
  > "$error_log"
  echo $$ > "$pid_file"

  function scan_domain() {
    local prefix=$1
    local depth=$2

    if [[ $depth -eq $length ]]; then
      local domain="${prefix}.${tld}"

      result=$(whois "$domain" 2>>"$error_log")
      if echo "$result" | grep -iqE "status: free|status: available|no entries found|NOT FOUND|No match"; then
        echo "$domain 未注册" >> "$status_file"
        echo "$domain" >> "$output_file"
      else
        echo "$domain 已注册" >> "$status_file"
      fi

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

function start_scan() {
  check_whois

  read -rp "请输入要扫描的域名后缀（例如de com net）: " tld

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
    read -rp "请输入要扫描的位数（例如 3）: " length
    if [[ "$length" =~ ^[1-9][0-9]*$ ]]; then
      break
    else
      echo "请输入有效的正整数"
    fi
  done

  cd "$BASE_DIR" || { echo "切换目录失败，退出"; exit 1; }

  nohup bash "$0" run_bg "$tld" "$char_type" "$length" > /dev/null 2>>"$error_log" &

  echo "后台扫描已启动，结果保存到 $output_file"
  echo "停止扫描：kill \$(cat $pid_file)"
  echo "卸载脚本：运行本脚本选择 2"
}

function view_status() {
  if [[ ! -f "$status_file" ]]; then
    echo "扫描状态文件不存在，暂无扫描任务"
    return
  fi

  echo "实时查看扫描状态，按 0 退出"

  tail -n 20 -f "$status_file" &
  tail_pid=$!

  # 不需要回车，直接读取单字符
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
  echo "2. 卸载脚本（停止扫描+删除文件）"
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
