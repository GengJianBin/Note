#!/bin/bash
set -euo pipefail

# ===================== 全局配置 =====================
ROS_DISTRO="jazzy"
UBUNTU_CODENAME="noble"
TARGET_UBUNTU_VERSION="24.04"
BASHRC_FILE="${HOME}/.bashrc"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO] $*${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $*${NC}"; }
error() { echo -e "${RED}[ERROR] $*${NC}"; }

# 错误捕获函数
exec_check() {
    local cmd="$1"
    local msg="$2"
    info "执行: ${cmd}"
    if ! eval "${cmd}"; then
        error "步骤失败：${msg}"
        exit 1
    fi
}

# ===================== 前置校验 =====================
info "============================================="
info "ROS2 Jazzy Jalisco 自动安装脚本 (Ubuntu 24.04)"
info "============================================="

# 检查是否为Ubuntu
if ! grep -qi ubuntu /etc/os-release; then
    error "仅支持 Ubuntu 系统，当前不是Ubuntu，退出"
    exit 1
fi

# 检查系统版本
CODENAME=$(lsb_release -cs)
VERSION=$(lsb_release -rs)
info "检测系统版本: ${VERSION} (${CODENAME})"

if [[ "${CODENAME}" != "${UBUNTU_CODENAME}" ]]; then
    error "系统不匹配！需要 Ubuntu ${TARGET_UBUNTU_VERSION} (${UBUNTU_CODENAME})"
    error "ROS2 Jazzy 不能安装在其他Ubuntu版本"
    exit 1
fi

# ===================== 步骤1：更新系统 & 配置UTF-8 =====================
info "===== 步骤1：系统更新 + 配置UTF-8语言环境 ====="
exec_check "sudo apt update && sudo apt upgrade -y" "系统更新失败"

exec_check "sudo apt install locales -y" "安装locales失败"
exec_check "sudo locale-gen en_US en_US.UTF-8" "生成locale失败"
exec_check "sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8" "更新locale配置失败"
export LANG=en_US.UTF-8

# ===================== 步骤2：启用Universe仓库 =====================
info "===== 步骤2：启用universe软件源 ====="
exec_check "sudo apt install software-properties-common -y" "安装依赖失败"
exec_check "sudo add-apt-repository universe -y" "添加universe仓库失败"

# ===================== 步骤3：导入ROS2密钥 & 添加源 =====================
info "===== 步骤3：配置ROS2官方软件源 ====="
exec_check "sudo apt install curl gnupg lsb-release -y" "安装curl/gnupg失败"

info "尝试下载ROS GPG密钥（github），失败会提示手动切换国内源"
if sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg; then
    info "密钥下载成功"
else
    error "密钥下载失败！网络访问github异常"
    warn "解决方案二选一："
    warn "1. 修改hosts；2. 使用清华ROS镜像源替代官方源"
    exit 1
fi

# 添加ros2源
exec_check "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null" "写入ros2源文件失败"
exec_check "sudo apt update" "刷新apt缓存失败"

# ===================== 步骤4：安装ROS2 desktop-full（推荐） =====================
info "===== 步骤4：安装 ros-${ROS_DISTRO}-desktop-full ====="
warn "如需切换desktop / ros-base，请修改脚本内安装命令"
exec_check "sudo apt install ros-${ROS_DISTRO}-desktop-full -y" "ROS2包安装失败"

# ===================== 步骤5：开发工具链 =====================
info "===== 步骤5：安装colcon、rosdep、编译工具 ====="
exec_check "sudo apt install python3-colcon-common-extensions python3-rosdep python3-vcstool build-essential -y" "开发工具安装失败"

# rosdep 初始化（仅首次）
if [ ! -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
    info "执行 rosdep init"
    exec_check "sudo rosdep init" "rosdep init失败"
else
    info "rosdep 已初始化，跳过rosdep init"
fi

info "执行 rosdep update（容易超时，超时建议使用国内rosdep镜像）"
exec_check "rosdep update" "rosdep update失败"

# ===================== 步骤6：写入环境变量到 ~/.bashrc =====================
info "===== 步骤6：持久化ROS环境变量写入 ${BASHRC_FILE} ====="
ROS_ENV_BLOCK="
# ROS2 Jazzy Jalisco
source /opt/ros/${ROS_DISTRO}/setup.bash
source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
export ROS_DOMAIN_ID=0
# 自定义快捷别名
alias r2j='source /opt/ros/${ROS_DISTRO}/setup.bash'
alias ws='cd ~/ros2_ws && source install/setup.bash'
alias build='cd ~/ros2_ws && colcon build --event-handlers console_direct+'
"

# 判断是否已经存在配置，避免重复追加
if grep -q "ROS2 Jazzy Jalisco" "${BASHRC_FILE}"; then
    warn ".bashrc 已存在ROS2 Jazzy配置，跳过写入"
else
    echo "${ROS_ENV_BLOCK}" >> "${BASHRC_FILE}"
    info "环境变量已写入 ${BASHRC_FILE}"
fi

# 当前终端临时生效
source /opt/ros/${ROS_DISTRO}/setup.bash

# ===================== 步骤7：安装机器人常用额外依赖 =====================
info "===== 步骤7：安装机器人开发常用包 ====="
exec_check "sudo apt install -y \
ros-${ROS_DISTRO}-tf2-tools \
ros-${ROS_DISTRO}-rosbag2-storage-mcap \
ros-${ROS_DISTRO}-rqt-common-plugins \
ros-${ROS_DISTRO}-robot-state-publisher \
ros-${ROS_DISTRO}-joint-state-publisher-gui \
ros-${ROS_DISTRO}-sensor-msgs ros-${ROS_DISTRO}-geometry-msgs ros-${ROS_DISTRO}-nav-msgs" "额外依赖安装失败"

# ===================== 步骤8：创建默认工作空间 =====================
info "===== 步骤8：初始化默认工作空间 ~/ros2_ws ====="
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws
exec_check "colcon build" "初次编译工作空间失败"
source install/setup.bash

# ===================== 步骤9：安装完成自检 =====================
info "===== 安装完成，开始环境自检 ====="
if command -v ros2 &> /dev/null; then
    info "✅ ros2 命令可用"
    ros2 --version
else
    error "❌ ros2 命令未找到！安装异常"
    exit 1
fi

info "============================================="
info "🎉 ROS2 Jazzy Jalisco 安装全部完成！"
info "💡 新开终端自动加载环境；当前终端执行：source ~/.bashrc"
info "💡 测试命令：终端1 ros2 run demo_nodes_cpp talker  终端2 ros2 run demo_nodes_cpp listener"
info "============================================="
