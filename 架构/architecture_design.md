# 视频会议 Qt 客户端 — 系统架构设计文档

> **版本**: v1.0  
> **作者**: 架构组  
> **状态**: Internal Review  
> **技术栈**: Qt 6.5 LTS + C++17 + CMake 3.20+ + Protobuf 3 + WebRTC

---

## 1. 设计目标

| 目标 | 说明 |
|------|------|
| **高稳定** | UI 崩溃不影响音视频通话，媒体异常不拖垮界面 |
| **低延迟** | 端到端延迟 < 200ms（同区域），视频帧率 ≥ 30fps |
| **跨平台** | 一套代码覆盖 Windows / macOS / Linux，移动端复用核心层 |
| **可扩展** | 插件化架构，新功能（白板/字幕/AI降噪）以 Module 接入 |
| **易维护** | 严格分层，单向依赖，每层可独立编译、测试、替换 |

---

## 2. 架构总览 — 八层分层架构

```
┌──────────────────────────────────────────────────────────────┐
│  L1  应用外壳层 (App Shell)                                  │
│      启动引导 / 登录认证 / 路由调度 / 窗口管理 / 更新升级       │
├──────────────────────────────────────────────────────────────┤
│  L2  UI 视图层 (View)                                       │
│      基础组件库(TDesign-Qt) / 业务页面(QWidget+QML) / 渲染层   │
├──────────────────────────────────────────────────────────────┤
│  L3  状态管理层 (State)                                      │
│      会议状态机(FSM) / 视图状态(ViewModel) / 数据模型(Model)   │
├──────────────────────────────────────────────────────────────┤
│  L4  业务逻辑层 (Business Logic)                             │
│      音视频控制 / 会控管理 / IM聊天 / 屏幕共享 / 协作功能       │
├──────────────────────────────────────────────────────────────┤
│  L5  SDK 桥接层 (Bridge)  ◀── 关键层：双进程 IPC            │
│      Facade接口封装 / IPC通信(Socket+Protobuf) / EventBus     │
├──────────────────────────────────────────────────────────────┤
│  L6  SDK 核心层 (SDK Core)                                   │
│      信令与房间 / 媒体引擎 / 编解码器 / 网络传输 / 基础设施     │
├──────────────────────────────────────────────────────────────┤
│  L7  平台适配层 (PAL)                                        │
│      Windows(macOS/Linux/移动端) 硬件抽象与系统 API 封装       │
├──────────────────────────────────────────────────────────────┤
│  L8  云端服务 (Cloud Services)                               │
│      房间服务 / SFU媒体服务 / 鉴权 / 调度 / 录制存储          │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. 各层详细设计

### 3.1 L1 — 应用外壳层 (App Shell)

**职责**: 进程入口、生命周期管理、跨平台窗口系统适配。

```
┌─────────────────────────────────────────────────────┐
│                  main() 入口                         │
├──────┬──────┬──────┬──────┬──────┬──────┬──────────┤
│Splash│ Auth │Router│Window│ Tray │Updater│  Logger  │
└──────┴──────┴──────┴──────┴──────┴──────┴──────────┘
        │              │
        ▼              ▼
  AccountManager   WindowManager
  (OAuth2/Ticket)  (多窗口/分屏/DPI)
```

**关键设计**:
- **单例容器**: 全局 ServiceLocator 注册各层核心服务，依赖注入
- **路由调度**: DeepLink / 命令行参数 → 解析 → 跳转对应页面
- **多进程模型**: UI 进程 + SDK 进程分离（详见 3.5 节）

### 3.2 L2 — UI 视图层 (View Layer)

**职责**: 所有用户可见的界面元素、交互响应、视频画面渲染。

**技术选型**:
- **QWidget**: 传统桌面控件（设置页、对话框、列表）
- **QML**: 动画密集型场景（会议主界面转场、表情动画）
- **QOpenGLWidget**: 视频画面渲染窗口
- **TDesign-Qt**: 统一设计语言组件库

**目录结构**:
```
src/ui/
├── components/          # 基础组件
│   ├── TMButton/
│   ├── TMDialog/
│   └── TMToast/
├── pages/               # 业务页面
│   ├── pre_meeting/     # 会前：预约、预检、等候室
│   ├── in_meeting/      # 会中：主页面
│   └── post_meeting/    # 会后：回放、纪要
├── render/              # 视频渲染
│   ├── VideoRendererGL  # OpenGL 渲染器
│   ├── VideoSurface     # QML 视频表面
│   └── SharePreview     # 共享预览
└── theme/               # 主题系统
    ├── ThemeEngine      # 运行时换肤
    └── tokens.json      # 设计 Token
```

**渲染管线**:
```
SDK 视频帧 (YUV/RGB)
    │
    ▼
FrameBuffer Pool (零拷贝)
    │
    ▼
QOpenGLShader (YUV→RGB 转换)
    │
    ▼
QOpenGLWidget::paintGL()
    │
    ▼
GPU 合成 → 屏幕输出
```

### 3.3 L3 — 状态管理层 (State Management)

**职责**: 管理会议全生命周期状态、视图状态、数据模型，确保 UI 与数据一致。

#### 3.3.1 会议状态机 (Meeting FSM)

```
        joinRoom()
            │
            ▼
    ┌─── Idle ───┐
    │            │  join()
    ▼            ▼
 Connecting  (连接中: 信令协商/ICE打洞)
    │
    │  onConnected
    ▼
 Connected ───────────┐
    │                 │ onRtmpLost / onIceRestart
    │ onUserLeave     ▼
    │         Reconnecting (自动重连: 指数退避)
    │                 │
    │ onLeave         │ onReconnected
    ▼                 │
 Leaving ─────────────┘
    │
    ▼
  Ended
```

**状态持久化**: 关键状态写入本地 KV 存储，崩溃恢复后可重建。

#### 3.3.2 视图状态 (ViewModel)

```cpp
struct MeetingViewModel {
    ViewMode   viewMode;       // Gallery / Speaker / Share
    QString    pinnedUserId;   // 固定画面用户
    QString    activeSpeaker;  // 当前说话人
    bool       selfMicOn;
    bool       selfCamOn;
    bool       handRaised;
    int        participantCount;
    NetworkQuality netQuality; // Excellent/Good/Poor
};
```

**数据绑定**: Qt Property + QML Binding / QWidget signal-slot，状态变更自动驱动 UI 刷新。

#### 3.3.3 数据模型 (Model)

| 模型 | 职责 | 存储 |
|------|------|------|
| ParticipantList | 参会者列表、角色、状态 | 内存 + 增量同步 |
| ChatMessageStore | 聊天消息、文件传输 | 内存 + SQLite |
| SubtitleStore | 实时字幕/转写缓存 | 环形缓冲区 |

### 3.4 L4 — 业务逻辑层 (Business Logic)

**职责**: 封装所有业务规则和命令，是 UI 与 SDK 之间的"翻译官"。

**模块划分**:

| 模块 | 核心类 | 职责 |
|------|--------|------|
| 音视频控制 | AVController | 设备枚举/切换/开关、音量调节、硬件检测 |
| 会控管理 | MeetingController | 静音管理、踢人、分组讨论、主持人转移 |
| 即时消息 | ChatController | 群聊/私聊、文件传输、消息撤回 |
| 屏幕共享 | ShareController | 区域选择、窗口捕获、标注、激光笔 |
| 协作功能 | CollabController | 字幕/转写、投票、白板、云端录制 |

**设计模式**:
- **命令模式**: 每个操作封装为 Command 对象，支持撤销/重做/排队
- **策略模式**: 编解码策略、网络策略可运行时切换
- **观察者模式**: 事件订阅分发，解耦业务模块

```cpp
// 示例：命令模式封装
class MuteCommand : public ICommand {
public:
    explicit MuteCommand(UserId target, bool mute);
    void execute() override;
    void undo() override;
private:
    UserId target_;
    bool mute_;
    bool prevState_;
};
```

### 3.5 L5 — SDK 桥接层 (Bridge Layer) ★ 核心层

**职责**: 隔离 UI 进程与媒体 SDK 进程，提供统一接口门面。

> **这是整个架构最关键的层**。视频会议客户端与普通 Qt 应用的最大区别就在于此——**双进程架构**。

#### 3.5.1 为什么需要双进程？

| 单进程风险 | 双进程方案 |
|-----------|-----------|
| UI 卡顿/崩溃 → 通话中断 | UI 进程崩溃，SDK 进程继续运行 |
| 主线程阻塞 → 视频卡顿 | 媒体线程独立，不受 UI 影响 |
| 内存泄漏累积 → OOM | 进程隔离，独立内存空间 |
| 升级 UI 需重启通话 | 可独立升级 UI 壳 |

#### 3.5.2 双进程通信架构

```
┌──────────────────────┐         IPC          ┌──────────────────────┐
│   UI 进程 (Qt)       │  ┌──────────┐       │   SDK 进程 (Core)    │
│                      │  │  Socket  │       │                      │
│  ┌────────────────┐  │  │  Pair    │       │  ┌────────────────┐  │
│  │  UI / State /  │──┼──┤  / Pipe  │───────┼─▶│  Media Engine  │  │
│  │  Business Logic│  │  │ Protobuf │       │  │  Codec / Net   │  │
│  └────────────────┘  │  └──────────┘       │  └────────────────┘  │
│                      │                      │                      │
│  Bridge (Client端)   │                      │  Bridge (Server端)   │
│  - TaskQueue         │                      │  - Dispatcher        │
│  - CallbackRegistry  │                      │  - WorkerPool        │
└──────────────────────┘                      └──────────────────────┘
```

#### 3.5.3 Facade 接口设计

```cpp
// ---- 会议控制 ----
class ConferenceAPI {
public:
    static ConferenceAPI& instance();
    
    // 异步接口，返回 TaskHandle 可取消
    TaskHandle joinRoom(const JoinConfig& config);
    TaskHandle leaveRoom();
    TaskHandle switchViewMode(ViewMode mode);
    
    // 事件订阅
    Connection subscribe(const std::string& event, EventCallback cb);
};

// ---- 设备控制 ----
class DeviceAPI {
public:
    std::vector<DeviceInfo> enumerateDevices(DeviceType type);
    TaskHandle setMicMute(bool mute);
    TaskHandle setCameraOn(bool on);
    TaskHandle setSpeakerVolume(int vol);
};

// ---- 屏幕共享 ----
class ShareAPI {
public:
    TaskHandle startScreenShare(const ShareArea& area);
    TaskHandle stopScreenShare();
    TaskHandle annotate(const Annotation& anno);
};

// ---- 消息 ----
class ChatAPI {
public:
    TaskHandle sendMessage(const ChatMessage& msg);
    Connection onMessageReceived(MessageCallback cb);
};
```

#### 3.5.4 IPC 通信协议

```protobuf
// ipc_message.proto
syntax = "proto3";

enum MessageType {
    REQUEST  = 0;
    RESPONSE = 1;
    EVENT    = 2;
    HEARTBEAT = 3;
}

message IPCMessage {
    uint64   seq_id      = 1;  // 序列号，用于请求-响应配对
    MessageType type      = 2;
    string   service     = 3;  // "Conference" / "Device" / "Share"
    string   method      = 4;  // "joinRoom" / "setMicMute"
    bytes    payload     = 5;  // 序列化参数
    int32    error_code  = 6;
    string   error_msg   = 7;
}
```

**序列化**: Protobuf（高性能场景）+ JSON（调试/日志场景）  
**传输**: Unix Domain Socket (Linux/macOS) / Named Pipe (Windows)  
**心跳**: 5s 间隔，超时 15s 判定对端异常

#### 3.5.5 EventBus 事件分发

```cpp
class EventBus {
public:
    // 发布事件 (SDK 进程 → UI 进程)
    void publish(const std::string& topic, const Event& event);
    
    // 订阅事件 (UI 进程)
    Connection subscribe(const std::string& topic, EventHandler handler);
    
    // 线程模型: 事件在 IO 线程接收，post 到 UI 线程派发
private:
    std::unordered_map<std::string, std::vector<EventHandler>> handlers_;
    QThread* ioThread_;
};
```

### 3.6 L6 — SDK 核心层 (SDK Core)

**职责**: 音视频通信的核心引擎，封装在独立进程中运行。

#### 3.6.1 信令与房间管理

| 组件 | 职责 |
|------|------|
| SignalingClient | WebSocket 长连接，收发信令消息 |
| RoomSession | 房间生命周期、成员管理、权限控制 |
| ICEAgent | NAT 穿透、Candidate 收集、连通性检查 |

#### 3.6.2 媒体引擎

```
音频采集 → 3A 处理(AEC/ANS/AGC) → 编码器(Opus) → RTP 打包 → 网络发送
                                                                    │
网络接收 → RTP 解包 → JitterBuffer → 解码器(Opus) → 3A 处理 → 音频播放
                                                                    │
视频采集 → 前处理(降噪/美颜) → 编码器(H.264/H.265) → RTP 打包 → 网络发送
                                                                    │
网络接收 → RTP 解包 → JitterBuffer → 解码器 → 后处理 → 渲染输出
```

**关键算法**:
- **JitterBuffer**: 动态抖动缓冲，自适应网络延迟
- **NetEQ**: 音频丢包补偿、变速不变调
- **FEC**: 前向纠错，抗丢包
- **Simulcast / SVC**: 多路流分层编码，适配不同带宽

#### 3.6.3 编解码器

| 类型 | 编码 | 硬件加速 |
|------|------|---------|
| 视频 | H.264 / H.265 / AV1 | NVENC / VideoToolbox / VA-API |
| 音频 | Opus / AAC | 无（CPU 足够） |

#### 3.6.4 网络传输

- **拥塞控制**: BBR / GCC (Google Congestion Control)
- **抗丢包**: ARQ (重传) + FEC (前向纠错) + RED (冗余编码)
- **智能路由**: 就近接入 SFU，多路径传输

### 3.7 L7 — 平台适配层 (PAL)

**职责**: 屏蔽操作系统差异，向上提供统一接口。

```
┌────────────────────────────────────────────────────────────┐
│                    PAL 统一接口 (IPLatformAPI)              │
├────────────┬────────────┬────────────┬────────────────────┤
│  Windows   │   macOS    │   Linux    │   移动端(iOS/And)   │
│  Direct3D  │   Metal    │  OpenGL    │   VideoToolbox/     │
│  WASAPI    │  CoreAudio │ PulseAudio │   MediaCodec        │
│  Win32 API │  Cocoa     │  X11/Way   │   AVFoundation      │
│  CryptoAPI │ Keychain   │   DBus     │   OpenSL ES         │
└────────────┴────────────┴────────────┴────────────────────┘
```

**实现方式**: 纯虚接口 + 工厂模式 + 条件编译

```cpp
// IPlatformAPI.h
class IPlatformAPI {
public:
    virtual ~IPlatformAPI() = default;
    virtual std::unique_ptr<IVideoCapture> createVideoCapture() = 0;
    virtual std::unique_ptr<IAudioDevice>  createAudioDevice() = 0;
    virtual std::unique_ptr<IGraphicsCtx>  createGraphicsContext() = 0;
    virtual std::string getSystemInfo() const = 0;
};

// 工厂
class PlatformFactory {
public:
    static std::unique_ptr<IPlatformAPI> create();
    // Windows → WinPlatformAPI
    // macOS   → MacPlatformAPI
    // Linux   → LinuxPlatformAPI
};
```

### 3.8 L8 — 云端服务 (Cloud Services)

| 服务 | 协议 | 职责 |
|------|------|------|
| 房间服务 | gRPC + WebSocket | 创建/销毁房间、成员管理、权限控制 |
| SFU 媒体服务 | WebRTC (UDP) | 多路流转发、Simulcast 分层、SVC 编码 |
| 鉴权服务 | HTTPS | Token 签发/校验、会议密码、E2EE 密钥协商 |
| 调度服务 | 内部 RPC | 就近接入、负载均衡、故障转移 |
| 录制服务 | 内部 RPC | 云端录制、转码封装、对象存储 |

---

## 4. 关键架构决策 (ADR)

### ADR-001: 双进程架构
- **决策**: UI 进程与 SDK 进程分离
- **理由**: 隔离崩溃域、保证通话稳定性、支持独立升级
- **代价**: IPC 通信开销、开发复杂度增加

### ADR-002: Protobuf over JSON for IPC
- **决策**: IPC 消息使用 Protobuf 序列化
- **理由**: 高性能（比 JSON 快 5-10x）、强类型、向后兼容
- **代价**: 需要 .proto 管理流程

### ADR-003: Qt 信号槽 + 单向数据流
- **决策**: UI 更新通过 Signal-Slot，状态变更单向流动
- **理由**: Qt 原生机制、调试友好、避免双向绑定混乱
- **代价**: 需要严格规范，防止滥用直接修改

### ADR-004: C++17 作为核心语言标准
- **决策**: SDK 核心使用 C++17
- **理由**: 性能可控、跨平台、ABI 稳定、现代语法提升可读性
- **代价**: 编译时间增加、部分旧平台不支持

### ADR-005: 插件化 Module 系统
- **决策**: 白板/字幕/AI 降噪等功能以 Module 形式动态加载
- **理由**: 核心包体积小、功能可灰度、第三方可扩展
- **代价**: 接口契约管理、版本兼容

---

## 5. 构建与工程化

```
project/
├── CMakeLists.txt          # 顶层构建
├── cmake/
│   ├── modules/            # CMake 模块
│   └── toolchains/         # 交叉编译工具链
├── src/
│   ├── shell/              # L1 应用外壳
│   ├── ui/                 # L2 UI 视图
│   ├── state/              # L3 状态管理
│   ├── business/           # L4 业务逻辑
│   ├── bridge/             # L5 SDK 桥接
│   ├── sdk/                # L6 SDK 核心
│   │   ├── signaling/
│   │   ├── media_engine/
│   │   ├── codec/
│   │   └── transport/
│   └── platform/           # L7 平台适配
│       ├── windows/
│       ├── macos/
│       └── linux/
├── proto/                  # Protobuf 定义
├── tests/                  # 单元测试
├── tools/                  # 构建工具
└── third_party/            # 第三方依赖
    ├── webrtc/
    ├── protobuf/
    └── qt6/
```

**CI/CD 流水线**:
```
代码提交 → 静态检查(clang-tidy) → 单元测试 → 多平台编译 → 集成测试 → 打包签名 → 发布
```

---

## 6. 性能预算

| 指标 | 目标值 | 测量方式 |
|------|--------|---------|
| 启动到可操作 | < 2s | 冷启动埋点 |
| 加入会议耗时 | < 1.5s | 从点击到首帧 |
| UI 帧率 | ≥ 60fps | Qt 帧率监控 |
| 视频渲染延迟 | < 50ms | GPU 时间戳 |
| 音频端到端延迟 | < 200ms | 回声测试 |
| 内存占用 (空闲) | < 150MB | 系统监控 |
| 内存占用 (会议中) | < 400MB (9人) | 压力测试 |
| CPU 占用 (会议中) | < 15% (中端机) | 性能分析 |

---

## 7. 安全设计

| 层面 | 措施 |
|------|------|
| 传输加密 | TLS 1.3 (信令) + SRTP (媒体) |
| 端到端加密 | 可选 E2EE，密钥不上云 |
| 认证授权 | OAuth2 + 会议密码 + 等候室 |
| 代码安全 | 二进制混淆、反调试、签名校验 |
| 隐私保护 | 本地数据处理、最小化采集 |

---

*© Architecture Blueprint — For Internal Review Only*
