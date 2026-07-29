# ROS2 常用命令行工具速查表（纯文本可直接保存）

适配：ROS2 Humble / Jazzy 通用 \| 用途：日常开发、调试、面试背诵、本地快速查阅

## 前置环境（必执行）

```Plain Text
# ROS2 Humble 环境
source /opt/ros/humble/setup.bash
# ROS2 Jazzy 环境
source /opt/ros/jazzy/setup.bash
# 本地工作空间环境
source install/setup.bash
```

## 一、包管理 pkg（项目开发最常用）

```Plain Text
# 创建C++功能包（主流开发）
ros2 pkg create --build-type ament_cmake 包名
# 创建Python功能包
ros2 pkg create --build-type ament_python 包名
# 创建包并批量添加依赖
ros2 pkg create --build-type ament_cmake 包名 --dependencies rclcpp rclcpp_action std_msgs geometry_msgs tf2_ros

# 查看所有已安装功能包
ros2 pkg list
# 搜索指定功能包
ros2 pkg find 包名
# 查看功能包安装路径
ros2 pkg prefix 包名
# 查看包配置信息
ros2 pkg xml 包名
```

## 二、节点操作 node

```Plain Text
# 列出所有运行中的节点
ros2 node list
# 查看节点详细信息（订阅/发布话题、服务、参数）
ros2 node info /节点名
```

## 三、话题调试 topic（高频调试命令）

```Plain Text
# 列出所有话题
ros2 topic list
# 列出话题+对应消息类型
ros2 topic list -t

# 打印话题实时数据
ros2 topic echo /话题名
# 仅打印一次话题数据
ros2 topic echo /话题名 --once
# JSON格式输出（适合脚本解析）
ros2 topic echo /话题名 --json

# 查看话题对应的消息类型
ros2 topic type /话题名

# 单次发布话题数据（测试用）
ros2 topic pub --once /话题名 消息类型 "{数据内容}"
# 固定频率发布话题（10Hz）
ros2 topic pub -r 10 /话题名 消息类型 "{数据内容}"

# 检测话题发布频率
ros2 topic hz /话题名
# 检测话题带宽占用
ros2 topic bw /话题名
```

## 四、服务调用 service

```Plain Text
# 列出所有运行中的服务
ros2 service list
# 列出服务+服务类型
ros2 service list -t
# 查看服务类型
ros2 service type /服务名
# 反向查找使用该类型的所有服务
ros2 service find 服务类型

# 调用服务
ros2 service call /服务名 服务类型 "请求参数"
```

## 五、动作通信 action（导航/机械臂专用）

```Plain Text
# 列出所有Action服务
ros2 action list
# 列出Action+类型
ros2 action list -t
# 查看Action类型
ros2 action type /动作名

# 发送Action目标指令
ros2 action send_goal /动作名 动作类型 "目标参数"
# 发送目标并实时打印反馈
ros2 action send_goal --feedback /动作名 动作类型 "目标参数"
```

## 六、消息/接口查看 interface（替代ROS1 rosmsg/rossrv）

```Plain Text
# 查看消息定义
ros2 interface show 消息类型
# 查看服务定义
ros2 interface show 服务类型
# 查看动作定义
ros2 interface show 动作类型

# 过滤查找接口
ros2 interface list | grep 关键字
```

## 七、参数配置 param（动态调参核心）

```Plain Text
# 查看节点所有参数
ros2 param list /节点名
# 获取指定参数值
ros2 param get /节点名 参数名
# 运行时动态修改参数
ros2 param set /节点名 参数名 参数值

# 导出节点参数为YAML文件
ros2 param dump /节点名 --output 保存名.yaml
# 从YAML文件加载参数到节点
ros2 param load /节点名 参数文件.yaml
```

## 八、节点/启动文件运行 run \& launch

```Plain Text
# 运行单个可执行节点
ros2 run 包名 可执行文件名

# 启动launch启动文件
ros2 launch 包名 launch文件名.py
# 启动launch并传参
ros2 launch 包名 launch文件名.py 参数名:=参数值
```

## 九、数据录制回放 bag（离线调试必备）

```Plain Text
# 录制指定话题
ros2 bag record /话题1 /话题2
# 录制所有话题
ros2 bag record -a
# 录制并压缩数据
ros2 bag record -a --compression-mode file
# 自定义文件名录制
ros2 bag record -o 自定义包名 /话题

# 查看bag包信息
ros2 bag info 包名

# 回放bag数据
ros2 bag play 包名
# 0.5倍慢速回放
ros2 bag play 包名 --rate 0.5
# 循环回放
ros2 bag play 包名 --loop
# 仿真时间回放（适配use_sim_time，关键命令）
ros2 bag play 包名 --clock
```

## 十、TF坐标变换工具

```Plain Text
# 实时查看两个坐标系的变换关系
ros2 run tf2_ros tf2_echo 源坐标系 目标坐标系
# 生成TF树PDF结构图
ros2 run tf2_tools view_frames
```

## 十一、日志调试命令

```Plain Text
# 全局设置日志级别（临时生效）
export ROS_LOG_LEVEL=WARN
# 单次运行节点指定日志级别
ros2 run 包名 节点名 --ros-args --log-level DEBUG
```

## 十二、DDS网络/环境调试

```Plain Text
# 查看当前使用的DDS协议
echo $RMW_IMPLEMENTATION

# 临时切换DDS为CycloneDDS
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
# 临时切换DDS为FastDDS
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

## 十三、可视化工具终端启动命令

```Plain Text
rqt                 # RQT综合调试面板
rqt_graph           # 节点与话题拓扑图
rqt_tf_tree         # 实时TF坐标树
rqt_console         # 日志可视化窗口
rqt_plot            # 数据曲线绘制
rviz2               # 机器人可视化工具
gazebo              # Humble仿真器
ign gazebo          # Jazzy仿真器
```

## 十四、通用实用技巧

```Plain Text
# 过滤查询内容
ros2 topic list | grep 关键字
ros2 pkg list | grep 关键字

# 查看所有命令帮助
ros2 指令名 -h
```

## 高频面试核心考点（命令相关）

1. **ros2 topic pub \-\-once / \-r**：once单次发布，\-r 指定固定频率持续发布

2. **ros2 bag play \-\-clock**：开启仿真时间同步，必须配合节点 use\_sim\_time:=true 使用，解决TF、导航时间错乱问题

3. ROS2 废弃 rosmsg/rossrv，统一使用 **ros2 interface**

4. **ros2 run vs ros2 launch**：run启动单个节点；launch可批量启动多节点、配置参数、命名空间、重映射

5. 动态调参：ros2 param set 可实时修改节点参数，无需重启节点

6. 话题收不到数据优先排查：QoS不匹配、命名空间、时间不同步、话题名拼写错误

> （注：部分内容可能由 AI 生成）
