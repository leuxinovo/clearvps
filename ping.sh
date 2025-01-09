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

# 遍历城市并测试延迟
for city in "${cities[@]}"; do
    # 提取城市名称和 IP 地址
    city_name=$(echo $city | cut -d':' -f1)
    ip_address=$(echo $city | cut -d':' -f2)
    
    # 执行 ping 命令并获取平均延迟时间
    ping_result=$(ping -c 4 $ip_address 2>/dev/null | tail -n 1 | awk '{print $4}' | cut -d '/' -f 2)

    # 如果没有成功获取延迟时间，设置为 "N/A"
    if [ -z "$ping_result" ]; then
        ping_result="N/A"
    fi

    # 根据运营商设置颜色并输出结果
    if [[ $city_name == *"联通"* ]]; then
        echo -n -e "${GREEN}$city_name: $ping_result ms${NC} | "
    elif [[ $city_name == *"电信"* ]]; then
        echo -n -e "${BLUE}$city_name: $ping_result ms${NC} | "
    elif [[ $city_name == *"移动"* ]]; then
        echo -n -e "${YELLOW}$city_name: $ping_result ms${NC} | "
    else
        echo -n -e "$city_name: $ping_result ms | "
    fi

    # 每三个城市换行
    ((counter++))
    if [ $counter -eq 3 ]; then
        echo ""
        counter=0
    fi
done

echo ""
echo "===================="
