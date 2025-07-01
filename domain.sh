#!/bin/bash

output_file="domain.txt"
pid_file="scan_domains.pid"

function cleanup() {
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if ps -p "$pid" > /dev/null 2>&1; then
      kill "$pid" && echo "已停止后台扫描进程（PID: $pid）"
    fi
    rm -f "$pid_file"
  fi
  rm -f "$output_file"
  echo "卸载完成，已删除 $output_file 和 $pid_file"
  exit 0
}

function run_scan_bg() {
  tld="$1"
  char_type="$2"
  length="$3"

  chars=()
  if [[ "$char_type" == "1" ]]; then
    chars=( {0..9} )
  elif [[ "$char_type" == "2" ]]; then
    chars=( {a..z} )
  elif [[ "$char_type" == "3" ]]; then
    chars=( {0..9} {a..z} )
  else
    echo "无效字符类型，退出"
    exit 1
  fi

  > "$output_file"
  echo $$ > "$pid_file"

  function scan_domain() {
    local prefix=$1
    local depth=$2

    if [[ $depth -eq $length ]]; then
      local domain="${prefix}.${tld}"
      result=$(whois "$domain" 2>/dev/null)
      if echo "$result" | grep -iqE "status: free|status: available|no entries found"; then
        echo "$domain" >> "$output_file"
      fi
      sleep 1
      return
    fi

    for c in "${chars[@]}"; do
      scan_domain "${prefix}${c}" $((depth + 1))
    done
  }

  scan_domain "" 0
  echo "扫描完成！"
  rm -f "$pid_file"
  exit 0
}

function start_scan() {
  echo "请输入要扫描的域名后缀（例如 de/com/net）:"
  read tld

  echo "请选择扫描字符类型："
  echo "1) 纯数字"
  echo "2) 纯字母"
  echo "3) 数字+字母混合"
  read char_type

  echo "请输入要扫描的位数（例如 3）:"
  read length

  echo "开始后台运行扫描，结果保存到 $output_file"
  nohup bash "$0" run_bg "$tld" "$char_type" "$length" >/dev/null 2>&1 &

  echo "后台扫描已启动，查看结果请查看 $output_file"
  echo "停止扫描：kill \$(cat $pid_file)"
  echo "卸载脚本：运行本脚本选择 2"
}

if [[ "$1" == "run_bg" ]]; then
  run_scan_bg "$2" "$3" "$4"
fi

# 主菜单
echo "请选择操作："
echo "1) 安装并开始扫描（后台运行）"
echo "2) 卸载脚本（停止扫描+删除文件）"
read choice

case "$choice" in
  1)
    start_scan
    ;;
  2)
    cleanup
    ;;
  *)
    echo "无效选择，退出"
    exit 1
    ;;
esac
