#!/usr/bin/env bash
set -e

if [[ $EUID -ne 0 ]]; then
   echo "错误：请使用 root 权限运行此脚本。" 
   exit 1
fi

if ! command -v rclone &> /dev/null; then
    echo "错误：未检测到 rclone，请先执行 ./tools/install_nodeget_backup.sh 安装依赖。"
    exit 1
fi

DB_DIR="/var/lib/nodeget-server"
DB_PATH="$DB_DIR/nodeget-server.db"
REMOTE_DIR="vps-gdrive:VPS_Backups/nodeget/nodeget-backup"

# 参数解析：如果传入了指定的文件名则使用，否则自动寻找最新的
TARGET_FILE=$1

if [[ -z "$TARGET_FILE" ]]; then
    echo "未指定要恢复的备份文件名，正在连接 Google Drive 自动寻找最新版本..."
    # 获取最新的 .db.bak 文件（按名称降序排列，由于包含日期，所以首个即为最新）
    LATEST=$(rclone lsf "$REMOTE_DIR" --include "nodeget-server_*.db.bak" | sort -r | head -n1)
    if [[ -z "$LATEST" ]]; then
        # 兜底：如果找不到带日期的，找有没有老的固定名称备份
        LATEST=$(rclone lsf "$REMOTE_DIR" --include "nodeget-server.db.bak" | head -n1)
    fi
    if [[ -z "$LATEST" ]]; then
        echo "错误：未在网盘目录 $REMOTE_DIR 中找到任何备份文件。"
        exit 1
    fi
    TARGET_FILE=$LATEST
    echo "自动定位到最新备份: $TARGET_FILE"
fi

echo "开始从 Google Drive 拉取备份..."
TMP_BAK="/tmp/$TARGET_FILE"
rclone copy "$REMOTE_DIR/$TARGET_FILE" "/tmp/" -v
if [[ ! -f "$TMP_BAK" ]]; then
    echo "错误：从网盘拉取文件失败！"
    exit 1
fi

echo "=========================================="
echo "⚠️ 准备覆盖数据库，正在停止 NodeGet 服务..."
systemctl stop nodeget-server 2>/dev/null || true

# 回滚保护
if [[ -f "$DB_PATH" ]]; then
    echo "正在备份当前可能损坏的库至 $DB_PATH.before-restore ..."
    mv "$DB_PATH" "$DB_PATH.before-restore"
fi

# 关键防损：必须删除可能残留的 WAL 缓存
rm -f "$DB_DIR/nodeget-server.db-shm" "$DB_DIR/nodeget-server.db-wal"

echo "正在注入备份的数据库..."
mv "$TMP_BAK" "$DB_PATH"
chown root:root "$DB_PATH"
chmod 644 "$DB_PATH"

echo "正在重启 NodeGet 服务..."
systemctl start nodeget-server
echo "=========================================="
echo "✅ 恢复完毕！你的 Token 及所有面板状态均已回档至该备份时刻。"
