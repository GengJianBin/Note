CMake find_package() 完整讲解
一、核心作用
find_package(<PackageName>)：在系统中查找第三方库 / 依赖包，自动完成：

    找到头文件路径（include directories）
    找到库文件路径（library paths）
    加载库编译选项、宏定义、目标链接规则
    提供导入目标（target）供后续 target_link_libraries() 使用

简单说：代替手动写 -I、-L、链接库，统一管理第三方依赖。
二、两种工作模式（非常关键）
1. Module 模式（传统方式，旧机制）
cmake

find_package(XXX)

CMake 会去搜索：
FindXXX.cmake 模块脚本
搜索目录顺序：

    CMAKE_MODULE_PATH（用户自定义优先）
    CMake 内置模块目录

原理：执行 FindXXX.cmake，脚本内部搜索头文件、库，最终定义变量：
plaintext

XXX_INCLUDE_DIRS   # 头文件路径
XXX_LIBRARIES      # 需要链接的库
XXX_FOUND          # 是否找到

使用方式：
cmake

if(XXX_FOUND)
  include_directories(${XXX_INCLUDE_DIRS})
  target_link_libraries(app ${XXX_LIBRARIES})
endif()

    缺点：纯变量管理，容易出现路径冲突、静态 / 动态库分不清、缺少版本、缺少依赖传递。

2. Config 模式（现代 CMake，推荐！）
cmake

find_package(XXX CONFIG)
# 或者简写（CMake自动优先尝试Config模式）
find_package(XXX)

寻找文件：XXXConfig.cmake / xxx-config.cmake
一般由库开发者安装库时一同提供。
核心特点：
✅ 提供 IMPORTED 导入目标（例如 XXX::XXX）
✅ 自带依赖关系、编译选项、库类型（静态 / 动态）
✅ 支持版本校验
✅ 不需要手动 include_directories
标准现代写法：
cmake

find_package(XXX REQUIRED)
target_link_libraries(app PRIVATE XXX::XXX)

链接目标时自动带上头文件路径、编译参数，CMake 自动处理一切。

    大部分新库（Qt5/6、Boost、OpenCV、abseil、protobuf）都优先提供 Config 文件。

三、常用参数说明
cmake

find_package(<PackageName>
  [version]                # 指定最低版本
  [EXACT]                  # 必须严格匹配版本
  [QUIET]                  # 找不到不打印警告
  [REQUIRED]               # 找不到直接终止构建，报错
  [COMPONENTS <comps...>]  # 选择库的子模块（典型：Qt）
  [OPTIONAL_COMPONENTS ...]
  [CONFIG|NO_MODULE]       # 强制使用Config模式
  [MODULE]                 # 强制使用Module模式
)

示例：
cmake

# 要求Qt6，必须包含Core、Gui组件，找不到直接报错
find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui)
target_link_libraries(app PRIVATE Qt6::Core Qt6::Gui)

四、查找路径优先级（搜索顺序）

    CMAKE_FIND_ROOT_PATH
    XXX_DIR（优先！可以手动设置 set(XXX_DIR "/path/lib/cmake/XXX")）
    系统标准路径 /usr/lib/cmake、/usr/local、Windows 注册表、环境变量
    交叉编译时受 CMAKE_FIND_ROOT_PATH_MODE_* 控制

    手动指定库路径最常用技巧：
    cmake

    set(OpenCV_DIR "/opt/opencv/lib/cmake/opencv4")
    find_package(OpenCV REQUIRED)

五、REQUIRED 的区别

    find_package(XXX)：找不到仅仅设置 XXX_FOUND=OFF，继续执行，需要自己判断
    find_package(XXX REQUIRED)：找不到直接 FATAL_ERROR，停止编译，适合必备依赖

六、Module 模式 vs Config 模式对比总结
表格
特性	Module 模式 (FindXXX.cmake)	Config 模式 (XXXConfig.cmake)
产物	变量 XXX_INCLUDE_DIRS	导入目标 XXX::XXX
头文件	需要手动 include_directories	链接目标自动携带
依赖传递	需要手动处理	自动传递依赖
版本支持	支持但不完善	原生完善版本校验
推荐程度	老旧项目兼容	现代 CMake 首选
七、常见误区

    ❌ 找到包之后忘记判断 XXX_FOUND（不加 REQUIRED 时）
    ❌ 混用旧变量模式和现代目标模式
    ❌ 不理解组件 COMPONENTS，Qt、Boost 必须正确指定组件
    ❌ 找不到库不知道设置 XXX_DIR

如果你需要，我可以给你一份通用模板，区分可选依赖 / 强制依赖，同时演示如何兼容新旧两种写法。