# 一、工作空间
工作空间就是一个目录，结构为：工作空间名称/src
# 二、功能包
创建命令为：ros2 pkg create demo_python_topic --build-type ament_python --dependencies rclpy example_interfaces --license Apache-2.0
# 三、编译
- 编译工作空间下的所有包
    colcon build
- 编译工作空间下的指定包
    colcon build --package-select 包名
# 四、添加依赖关系
- package.xml 是 ROS2 功能包（Package）的清单描述文件，放在每个功能包根目录，是 ROS2 识别文件夹为合法功能包的核心文件。
# 五、环境变量AMENT_PREFIX_PATH
AMENT_PREFIX_PATH 环境变量的默认值为ROS2系统的安装目录
包的安装目录在编译后的install目录下，需要修改AMENT_PREFIX_PATH变量的直：执行 source install/setup.sh即可