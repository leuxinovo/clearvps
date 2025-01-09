#!/bin/bash

# 定义中国主要城市的 IP 地址或域名
cities=(
    "河北电信:101.96.149.46"
    "河北联通:101.28.249.31"
    "河北移动:111.62.140.222"
    "深圳:203.107.6.88"
    "成都:123.56.135.71"
    "杭州:114.115.140.69"
    "武汉:139.196.234.249"
    "重庆:180.97.81.178"
    "沈阳:202.108.22.5"
    "南京:120.132.0.3"
)

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
    ping_result=$(ping -c 4 $ip_address | tail -n 1 | awk '{print $4}' | cut -d '/' -f 2)

    # 如果没有成功获取延迟时间，设置为 "N/A"
    if [ -z "$ping_result" ]; then
        ping_result="N/A"
    fi

    # 输出结果，每三列换行
    echo -n "$city_name: $ping_result ms  "
    
    # 每三个城市换一行
    ((counter++))
    if [ $counter -eq 3 ]; then
        echo ""
        counter=0
    fi
done

echo "===================="