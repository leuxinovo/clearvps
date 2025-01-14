#!/bin/bash

# 定义中国主要城市的 IP 地址（IPv4）
cities_ipv4=(
    "河北电信:101.96.149.46"
    "河北联通:101.28.249.31"
    "河北移动:111.62.140.222"
    "北京电信:43.243.235.24"
    "北京联通:123.125.46.42"
    "北京移动:111.132.36.94"
    "上海电信:61.147.211.30"
    "上海联通:220.249.135.45
"
    "上海移动:117.144.98.184"
    "广东电信:183.6.211.61"
    "广东联通:112.90.42.8"
    "广东移动:120.233.1.109"
)

# 颜色设置
BLUE='\033[0;34m'      # 电信（蓝色）
GREEN='\033[0;32m'     # 联通（深绿色）
YELLOW='\033[1;33m'    # 移动（黄色）
NC='\033[0m'           # 默认颜色（无颜色）

# 输出标题
echo "Leu三网延迟测试"
echo "===================="

# 开始测试 IPv4 延迟
echo "开始测试 IPv4 延迟..."
counter=0

# 定义每列的最大宽度（适应中文字符和英文字符的混合情况）
city_width=15
ping_width=6  # 缩小ping宽度，减少ms和:之间的距离

# 获取延迟结果的函数
get_ping_result() {
    local address=$1
    local result
    result=$(ping -c 4 $address 2>/dev/null | tail -n 1 | awk '{print int($4)}' | cut -d '/' -f 2)
    echo "$result"
}

# 测试 IPv4 地址
for city in "${cities_ipv4[@]}"; do
    # 提取城市名称和IPv4地址
    city_name=$(echo $city | cut -d':' -f1)
    ipv4_address=$(echo $city | cut -d':' -f2)

    # 获取IPv4延迟
    ipv4_ping_result=$(get_ping_result "$ipv4_address")

    # 格式化输出
    if [[ $city_name == *"联通"* ]]; then
        formatted_result_ipv4=$(printf "${GREEN}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
    elif [[ $city_name == *"电信"* ]]; then
        formatted_result_ipv4=$(printf "${BLUE}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
    elif [[ $city_name == *"移动"* ]]; then
        formatted_result_ipv4=$(printf "${YELLOW}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
    else
        formatted_result_ipv4=$(printf "%-${city_width}s: %-${ping_width}s ms" "$city_name" "$ipv4_ping_result")
    fi
    echo -n "$formatted_result_ipv4 | "

    # 每三个城市换行
    ((counter++))
    if [ $counter -eq 3 ]; then
        echo ""
        counter=0
    fi
done

echo ""
echo "===================="
