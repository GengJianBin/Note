#!/bin/bash
set -e

# ===================== 配置区 =====================
# 替换为你自己的邮箱（git注册邮箱）
GIT_EMAIL="13684522822@163.com"
# 密钥文件名
SSH_KEY_NAME="id_ed25519"
# ==================================================

SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/$SSH_KEY_NAME"
PUBLIC_KEY="${PRIVATE_KEY}.pub"

echo "====================================="
echo "      Git SSH 密钥自动配置脚本"
echo "====================================="

# 1. 创建 .ssh 目录
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# 2. 判断密钥是否已存在
if [ -f "${PRIVATE_KEY}" ]; then
    echo "✅ 检测到已有密钥 ${PRIVATE_KEY}，跳过生成"
else
    echo "🔐 开始生成 ed25519 SSH密钥..."
    ssh-keygen -t ed25519 -C "${GIT_EMAIL}" -f "${PRIVATE_KEY}"
    chmod 600 "${PRIVATE_KEY}"
    echo "✅ 密钥生成完成"
fi

# 3. 启动 ssh-agent
echo "📌 启动 ssh-agent"
eval "$(ssh-agent -s)"

# 4. 添加私钥到agent
ssh-add "${PRIVATE_KEY}"

# 5. 生成SSH Config（多平台git示例）
SSH_CONFIG="${SSH_DIR}/config"
cat > "${SSH_CONFIG}" << EOF
# GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ${PRIVATE_KEY}
  IdentitiesOnly yes

# Gitee
Host gitee.com
  HostName gitee.com
  User git
  IdentityFile ${PRIVATE_KEY}
  IdentitiesOnly yes

# GitLab
Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile ${PRIVATE_KEY}
EOF
chmod 644 "${SSH_CONFIG}"
echo "✅ ~/.ssh/config 写入完成"

# 6. 打印公钥
echo -e "\n==================== 公钥（复制全部）===================="
cat "${PUBLIC_KEY}"
echo -e "\n========================================================"
echo "📝 操作步骤："
echo "1. 将上面公钥复制，粘贴到对应平台："
echo "   GitHub: Settings -> SSH and GPG keys -> New SSH key"
echo "   Gitee: 设置 -> SSH公钥"
echo "2. 添加完成后执行下面命令测试连通："
echo "   测试GitHub: ssh -T git@github.com"
echo "   测试Gitee: ssh -T git@gitee.com"
echo -e "\n💡 提示：首次连接输入 yes 确认信任主机"
