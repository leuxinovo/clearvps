#!/bin/bash

# 定义中国主要城市的 IP 地址或域名
cities=(
    "河北电信:101.96.149.46"
    "河北联通:101.28.249.31"
    "河北移动:111.62.140.222"
    "北京电信:43.243.235.24"
    "北京联通:123.125.46.42"
    "北京移动:111.132.36.94"
    "上海电信:61.147.211.30"
    "上海联通:140.206.239.47"
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
echo "中国地区延迟测试"
echo "===================="
echo ""

# 初始化计数器
counter=0

# 定义每列的最大宽度（适应中文字符和英文字符的混合情况）
city_width=15
ping_width=6  # 缩小ping宽度，减少ms和:之间的距离

# 遍历城市并测试延迟
for city in "${cities[@]}"; do
    # 提取城市名称和 IP 地址
    city_name=$(echo $city | cut -d':' -f1)
    ip_address=$(echo $city | cut -d':' -f2)
    
    # 执行 ping 命令并获取平均延迟时间，去掉小数点后的数字
    ping_result=$(ping -c 4 $ip_address 2>/dev/null | tail -n 1 | awk '{print int($4)}' | cut -d '/' -f 2)

    # 如果没有成功获取延迟时间，设置为 "N/A"
    if [ -z "$ping_result" ]; then
        ping_result="N/A"
    fi

    # 根据延迟值来调整输出格式
    if [ "$ping_result" != "N/A" ] && [ ${#ping_result} -le 2 ]; then
        ping_result="$ping_result "  # 给两位数的延迟后加一个空格
    fi

    # 根据运营商设置颜色并格式化输出
    if [[ $city_name == *"联通"* ]]; then
        formatted_result=$(printf "${GREEN}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ping_result")
    elif [[ $city_name == *"电信"* ]]; then
        formatted_result=$(printf "${BLUE}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ping_result")
    elif [[ $city_name == *"移动"* ]]; then
        formatted_result=$(printf "${YELLOW}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ping_result")
    else
        formatted_result=$(printf "%-${city_width}s: %-${ping_width}s ms" "$city_name" "$ping_result")
    fi

    # 输出格式化结果并加上竖线
    echo -n "$formatted_result | "

    # 每三个城市换行
    ((counter++))
    if [ $counter -eq 3 ]; then
        echo ""
        counter=0
    fi
done

echo ""
echo "===================="
