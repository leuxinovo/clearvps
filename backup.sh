#!/bin/bash

# 读取配置文件中的备份目录
CONFIG_FILE="backup_dirs.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "配置文件 $CONFIG_FILE 不存在！"
  exit 1
fi

# 读取配置文件中的目录并存储到数组
LOCAL_DIRS=()
while IFS= read -r line; do
  # 忽略空行和注释行
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  LOCAL_DIRS+=("$line")
done < "$CONFIG_FILE"

# 检查是否有要备份的目录
if [ ${#LOCAL_DIRS[@]} -eq 0 ]; then
  echo "配置文件中没有有效的备份目录！"
  exit 1
fi

REMOTE_USER="root"           # 远程 VPS 的用户名 默认root
REMOTE_HOST="remote_ip"      # 远程 VPS 的 IP 地址
REMOTE_DIR="/path/backup"    # 远程备份存储的目录
DATE=$(date +%Y-%m-%d_%H-%M-%S)  # 格式化日期为：2025-01-22_14-30-00
HOSTNAME=$(hostname)         # 获取当前主机名

# 创建备份文件名
BACKUP_NAME="backup_${HOSTNAME}_${DATE}.tar.gz"

# 创建备份文件
tar -czf $BACKUP_NAME "${LOCAL_DIRS[@]}"  # 使用数组中的目录来备份

# 确保备份文件创建成功
if [ ! -f "$BACKUP_NAME" ]; then
  echo "创建备份文件失败！"
  exit 1
fi

echo "备份文件已创建：$BACKUP_NAME"

# 确保远程备份目录存在
ssh $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR"

# 使用 scp 上传备份文件到远程 VPS
if scp -p $BACKUP_NAME $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR; then
  echo "备份文件上传成功"
  # 删除本地备份文件
  rm $BACKUP_NAME
else
  echo "上传备份文件失败！"
  exit 1
fi

# 清理远程备份目录，最多保留 3 个备份文件
ssh $REMOTE_USER@$REMOTE_HOST "
  cd $REMOTE_DIR;
  # 获取备份文件的列表，按时间排序，删除最旧的备份文件（超过 3 个）
  ls -t backup_*.tar.gz | sed -e '1,3d' | xargs -I {} rm -f {}
"

# 记录备份日志，使用北京时间
echo "备份文件 $BACKUP_NAME 于 $(date) 完成" >> /var/log/backup.log
