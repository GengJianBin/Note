#!/bin/bash
set -e

echo "===== ROS2 Humble Install for Ubuntu22.04.5 ====="
sudo apt update && sudo apt upgrade -y
sudo apt install -y locales curl gnupg lsb-release

# 语言配置
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# 导入密钥
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# 添加源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt update

# 安装完整桌面版
sudo apt install -y ros-humble-desktop ros-dev-tools

# 写入环境变量
if ! grep -q "source /opt/ros/humble/setup.bash" ~/.bashrc; then
  echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
fi

# 创建工作空间
mkdir -p ~/colcon_ws/src
cd ~/colcon_ws
colcon build --symlink-install

if ! grep -q "source ~/colcon_ws/install/setup.bash" ~/.bashrc; then
  echo "source ~/colcon_ws/install/setup.bash" >> ~/.bashrc
fi

source ~/.bashrc
echo "======================================"
echo "ROS2 Humble 安装完成！新开终端生效"
echo "测试命令：ros2 run demo_nodes_cpp talker"
