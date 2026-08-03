#!/usr/bin/env bash
set -e

if [[ $EUID -ne 0 ]]; then
   echo "错误：请使用 root 权限运行此脚本。" 
   exit 1
fi

if ! command -v rclone &> /dev/null; then
    echo "未检测到 rclone，正在使用官方轻量脚本安装以防内存溢出..."
    curl -fsSL https://rclone.org/install.sh | bash
fi

echo "=========================================================="
echo "准备恢复 rclone Google Drive 配置文件 (vps-gdrive)"
echo "请前往你之前成功配置过的主机，查看 /root/.config/rclone/rclone.conf 文件"
echo "并复制其中 'token =' 后面的那一大段 JSON 字符串。"
echo "格式类似于: {\"access_token\":\"ya29...\",\"token_type\":\"Bearer\",...}"
echo "=========================================================="
echo ""
read -r -p "1. 请输入专属 Client ID (若无，直接回车跳过): " client_id
read -r -p "2. 请输入专属 Client Secret (若无，直接回车跳过): " client_secret
read -r -p "3. 请粘贴核心的 token JSON 字符串并回车: " token

if [[ -z "$token" ]]; then
    echo "错误: Token 不能为空。"
    exit 1
fi

mkdir -p /root/.config/rclone

# 动态组装配置文件，有 client_id 才会写入对应行
cat > /root/.config/rclone/rclone.conf <<EOF
[vps-gdrive]
type = drive
$([[ -n "$client_id" ]] && echo "client_id = $client_id")
$([[ -n "$client_secret" ]] && echo "client_secret = $client_secret")
scope = drive.file
team_drive = 
token = $token
EOF

chmod 600 /root/.config/rclone/rclone.conf

echo "✅ Rclone 配置已成功恢复！"
echo "正在测试连接..."
rclone lsd vps-gdrive: --max-depth 1 || echo "⚠️ 连接测试失败，请检查 token 是否已过期或粘贴错误。"
echo "测试完成。"
