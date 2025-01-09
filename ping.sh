#!/bin/bash

# 定义中国主要城市的 IP 地址或域名（IPv4 和 IPv6）
cities=(
    "河北电信:101.96.149.46:240e:940:60a:1:3::29"   # IPv4 和 IPv6 地址
    "河北联通:101.28.249.31:2408:871a:6010:a:3::7f7"
    "河北移动:111.62.140.222:2409:8c04:110e:c:3::3f6"
    "北京电信:43.243.235.24:240e:904:800:100::6e"
    "北京联通:123.125.46.42:2408:8706:0:5900::27"
    "北京移动:111.132.36.94:2409:8c02:24c:c0::38"
    "上海电信:61.147.211.30:240e:96c:6000:2100::cf"
    "上海联通:140.206.239.47:2408:80f1:1b0:5:4000::3a"
    "上海移动:117.144.98.184:2409:871e:8200:8::ca"
    "广东电信:183.6.211.61:240e:97d:201c:201::36"
    "广东联通:112.90.42.8:2408:8756:e2ff:100::71"
    "广东移动:120.233.1.109:2409:8c54:4840:300::56"
)

# 颜色设置
BLUE='\033[0;34m'      # 电信（蓝色）
GREEN='\033[0;32m'     # 联通（深绿色）
YELLOW='\033[1;33m'    # 移动（黄色）
NC='\033[0m'           # 默认颜色（无颜色）

# 输出标题
echo "Leu三网延迟测试"
echo "===================="
echo ""

# 提供用户选择
echo "请选择要进行的延迟测试类型："
echo "1.IPv4"
echo "2.IPv6"
read -p "请输入您的选择 (1/2): " choice

# 初始化计数器
counter=0

# 定义每列的最大宽度（适应中文字符和英文字符的混合情况）
city_width=15
ping_width=6  # 缩小ping宽度，减少ms和:之间的距离

# 根据用户选择执行相应的测试
for city in "${cities[@]}"; do
    # 提取城市名称、IPv4 和 IPv6 地址
    city_name=$(echo $city | cut -d':' -f1)
    ipv4_address=$(echo $city | cut -d':' -f2)
    ipv6_address=$(echo $city | cut -d':' -f3)

    # 执行选择的ping命令并获取延迟时间
    if [ "$choice" == "1" ]; then
        # 执行 IPv4 ping 命令并获取延迟时间，去掉小数点后的数字
        ipv4_ping_result=$(ping -c 4 $ipv4_address 2>/dev/null | tail -n 1 | awk '{print int($4)}' | cut -d '/' -f 2)
        if [ -z "$ipv4_ping_result" ]; then
            ipv4_ping_result="N/A"
        fi
        if [ "$ipv4_ping_result" != "N/A" ] && [ ${#ipv4_ping_result} -le 2 ]; then
            ipv4_ping_result="$ipv4_ping_result "  # 给两位数的延迟后加一个空格
        fi
    fi

    if [ "$choice" == "2" ]; then
        # 执行 IPv6 ping 命令并获取延迟时间，去掉小数点后的数字
        ipv6_ping_result=$(ping6 -c 4 $ipv6_address 2>/dev/null | tail -n 1 | awk '{print int($4)}' | cut -d '/' -f 2)
        if [ -z "$ipv6_ping_result" ]; then
            ipv6_ping_result="N/A"
        fi
        if [ "$ipv6_ping_result" != "N/A" ] && [ ${#ipv6_ping_result} -le 2 ]; then
            ipv6_ping_result="$ipv6_ping_result "  # 给两位数的延迟后加一个空格
        fi
    fi

    # 根据延迟值来调整输出格式
    if [ "$choice" == "1" ]; then
        if [[ $city_name == *"联通"* ]]; then
            formatted_result_ipv4=$(printf "${GREEN}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
        elif [[ $city_name == *"电信"* ]]; then
            formatted_result_ipv4=$(printf "${BLUE}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
        elif [[ $city_name == *"移动"* ]]; then
            formatted_result_ipv4=$(printf "${YELLOW}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv4_ping_result")
        else
            formatted_result_ipv4=$(printf "%-${city_width}s: %-${ping_width}s ms" "$city_name" "$ipv4_ping_result")
        fi
    fi

    if [ "$choice" == "2" ]; then
        if [[ $city_name == *"联通"* ]]; then
            formatted_result_ipv6=$(printf "${GREEN}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv6_ping_result")
        elif [[ $city_name == *"电信"* ]]; then
            formatted_result_ipv6=$(printf "${BLUE}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv6_ping_result")
        elif [[ $city_name == *"移动"* ]]; then
            formatted_result_ipv6=$(printf "${YELLOW}%-${city_width}s: %-${ping_width}s ms${NC}" "$city_name" "$ipv6_ping_result")
        else
            formatted_result_ipv6=$(printf "%-${city_width}s: %-${ping_width}s ms" "$city_name" "$ipv6_ping_result")
        fi
    fi

    # 输出格式化结果并加上竖线
    if [ "$choice" == "1" ]; then
        echo -n "$formatted_result_ipv4 | "
    fi
    if [ "$choice" == "2" ]; then
        echo -n "$formatted_result_ipv6 | "
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
