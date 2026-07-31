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

# 八、运行
执行 ros2 run 报名 python_node ，其中python_node 为在setup.py中指定的

# 九、cpp开发流程
- 切换到工作空间的src目录下： 
```bash
ros2 pkg create demo_cpp_topic --build-type ament_cmake --dependencies rclcpp geometry turtlesim --license Apach-2.0
```

- 切换到功能包下的src目录创建源文件
- 修改CMakeList.txt文件
```txt
add_executable(turtle_circle src/turtle_circle.cpp)
ament_target_dependencies(turtle_circle rclcpp geometry_msgs)
install(TARGETS turtle_circle DESTINATION lib/${PROJECT_NAME})
```
- 运行海龟模拟器
```bash
ros2 run turtlesim turtlesim_node
```
- 运行节点
```bash
ros2 run demo_cpp_topic turtle_circle
```
注意：注意话题发布的名称，要写对