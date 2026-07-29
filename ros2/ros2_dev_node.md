# 一、工作空间
工作空间就是一个目录，结构为：工作空间名称/src
# 二、功能包
创建命令为：ros2 pkg create demo_python_topic --build-type ament_python --dependencies rclpy example_interfaces --license Apache-2.0
# 三、setup.py中添加main函数的位置
    将 python_node=demo_python_topic.novel_pub_node:main 添加到setup.py中的console_scripts下
# 四、编译
- 编译工作空间下的所有包
    colcon build
- 编译工作空间下的指定包
    colcon build --package-select 包名
# 五、添加依赖关系
- package.xml 是 ROS2 功能包（Package）的清单描述文件，放在每个功能包根目录，是 ROS2 识别文件夹为合法功能包的核心文件。
# 六、环境变量AMENT_PREFIX_PATH
AMENT_PREFIX_PATH 环境变量的默认值为ROS2系统的安装目录
包的安装目录在编译后的install目录下，需要修改AMENT_PREFIX_PATH变量的直：执行 source install/setup.sh即可

# 七、查看接口
ros2 interface show example_interfaces/msg/String