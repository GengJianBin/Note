SH 配置 Git 一键脚本（Linux/macOS/WSL 通用）
# 一、功能：

    检查是否存在 ssh key，不存在则生成 ed25519 密钥（推荐，安全性优于 RSA）
    创建 .ssh 目录、权限加固
    输出公钥，方便复制到 GitHub/Gitee/GitLab 账号
    生成 ssh config 模板，支持多 git 平台
    提供测试连通性命令

# 二、使用方法

    修改脚本内 GIT_EMAIL="your_email@example.com" 改成你的邮箱
    赋予执行权限

bash

chmod +x setup_git_ssh.sh

    运行

bash

./setup_git_ssh.sh

    ⚠️ 运行过程会提示设置密钥密码（可选，建议设置，提升安全）