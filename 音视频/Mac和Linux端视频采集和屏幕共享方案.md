# Mac 和 Linux 端视频采集与屏幕共享方案

Mac 和 Linux 两端的视频采集 + 屏幕共享，核心差异在**显示服务架构和权限模型**：macOS 走 Apple 私有框架（AVFoundation → ScreenCaptureKit），Linux 分 X11 老路和 Wayland+PipeWire 新路。下面按"采集接口 / 编码封装 / 现成工具 / 自研落地"四层给出可执行的对照方案。

---

## 一、macOS 端方案

### 1. 采集接口选型

#### ScreenCaptureKit（macOS 13.3+，首选）
- 苹果官方现代框架，`SCStream` + `SCContentFilter` 可按**显示器 / 单个窗口 / 指定 App** 过滤采集，输出 `CVPixelBuffer`（GPU 内存，零拷贝）。
- 同时采**系统音频**（macOS 13+）和**麦克风**（macOS 15+ 原生支持，老版本需单独 AVFoundation 采麦后混音）。
- 权限：必须在 **系统设置 → 隐私与安全性 → 屏幕录制** 授权（TCC），沙盒 App 还要配 entitlements，首次弹窗后需重启进程生效。

#### AVFoundation `AVCaptureScreenInput`（兼容 macOS 10.7+）
- 命令式绑定 `displayID`，能采屏+麦，**不能采系统音频**，CPU 占用高于 SCK，适合要覆盖老系统的兜底路径。

#### FFmpeg `-f avfoundation`
- 轻量录屏可用：`ffmpeg -f avfoundation -i "1:none" ...`，本质是套 AVFoundation，无系统声音，适合命令行/常驻低帧日志录制。

#### Electron `desktopCapturer`
- 跨平台桌面应用直接用，底层在 Mac 调 SCK/AVFoundation，但不解决混音和回声消除，需自行处理音频轨道。

### 2. 编码与推流
- **视频**：`CVPixelBuffer` 直接送 **VideoToolbox** 硬编 H.264/H.265，零拷贝最省电。
- **封装/推流**：用 `AVAssetWriter` 落盘，或用 WebRTC/RTP 推远端。
- **系统自带**：`Cmd+Shift+5` 快速录屏；**系统设置 → 共享 → 屏幕共享** 开 VNC Server（5900 端口）做被控。

---

## 二、Linux 端方案（X11 / Wayland 两套世界）

> 先判断会话类型：`echo $XDG_SESSION_TYPE` → `x11` 或 `wayland`。2024+ 的 Ubuntu/Fedora/GNOME/KDE 默认 Wayland，**X11 的 x11grab 在 Wayland 下拿不到画面**。

### 1. X11 环境（老服务器/远程桌面常用）

#### FFmpeg `x11grab`
```bash
ffmpeg -f x11grab -s 1920x1080 -i :0.0+0,0 -f pulse -c:v libx264 out.mp4
```
- 配合 `-f pulse` 采系统声，简单直接但纯软采软编，4K 吃 CPU。

#### OBS `Screen Capture (XSHM)` / `Window Capture (XComposite)`
- 共享内存或 Composite 离屏，性能够用。

#### 权限
- 同一用户会话内一般无需额外授权，root 下要注意 `$DISPLAY` 和 xauth。

### 2. Wayland 环境（现代发行版标配）

#### PipeWire + xdg-desktop-portal（唯一正确路径）
- 任何 App 想采屏都必须走 `xdg-desktop-portal` → compositor 弹窗让用户选屏幕/窗口 → PipeWire 以 **DMA-BUF** 把帧喂给消费者，零拷贝。
- 配套组件：PipeWire 0.3.50+ 跑音频视频，**portal 后端必须匹配 compositor**：
  - GNOME → `xdg-desktop-portal-gnome`
  - KDE → `xdg-desktop-portal-kde`
  - Sway / Hyprland（wlroots）→ `xdg-desktop-portal-wlr`
- 单次采集权限可"记住选择"，但每次新 App 首次采屏仍会弹 portal 对话框，无法完全静默（安全模型决定）。

#### OBS `Screen Capture (PipeWire)`
- Wayland 下唯一能用的 OBS 源，窗口/显示器/单 App 音频都能选；编码器用 **NVENC（N 卡）或 VAAPI（Intel/AMD）** 硬编。

#### wf-recorder（命令行）
```bash
wf-recorder -a -f out.mp4              # 全屏+音频
wf-recorder -a -g "$(slurp)" -f area.mp4  # 选区域录制
```
- 纯 Wayland 原生，不依赖 X11。

#### 自研采集
- C/Go/Rust 里用 `libpipewire` 订阅 `screen-share` 节点，拿到 `DMABUF` 或 `MemFd` 纹理，再送 VA-API 硬编。

### 3. Linux 屏幕共享/被控协议
- **GNOME Remote Desktop / Krfb**：GNOME 42+、KDE Plasma 自带，底层走 PipeWire+VNC，Ubuntu 22.04+/Fedora 直接可用。
- **xrdp**：让 Linux 伪装成 Windows RDP 服务端，混合环境有用，但 Wayland 下需额外桥接。
- **RustDesk / NoMachine**：跨平台统一客户端，自研成本最低，底层也是 PipeWire(X11) + SCK(Mac)。

---

## 三、两端对照速查表

| 维度 | macOS | Linux (X11) | Linux (Wayland) |
|---|---|---|---|
| 首选采集 API | ScreenCaptureKit (13.3+) | x11grab / XShm | PipeWire + xdg-portal |
| 窗口级过滤 | 原生 SCContentFilter | XComposite（有限） | portal 选窗口 / PW 节点 |
| 系统音频 | SCK 原生支持 | PulseAudio 抓源 | PipeWire 节点选择 |
| 硬编 | VideoToolbox | 无（或 NVENC 独显） | VA-API / NVENC |
| 权限模型 | TCC 屏幕录制授权 | 同用户会话即可 | portal 每次弹窗授权 |
| 零拷贝路径 | CVPixelBuffer → VT | 否 | DMA-BUF → VA-API |
| 快速录屏 | Cmd+Shift+5 | wf-recorder（需 Wayland） | wf-recorder / OBS |
| 被控/共享协议 | VNC (5900) | VNC / x11vnc | GNOME RD / Krfb / xrdp |

---

## 四、自研跨平台采集层落地建议

### 1. 抽象一层 CaptureBackend
- Mac 返回 `CVPixelBuffer` 池
- Linux-X11 返回 `XImage` / SHM 段
- Linux-Wayland 返回 PW `DMABUF` fd
- 上层统一转纹理做编码

### 2. 编码统一走硬编
- **Mac** → VideoToolbox
- **Linux** → VA-API（Intel/AMD）或 CUDA/NVENC（N 卡）
- 避免 4K 下 x264 软编拖垮 UI

### 3. 音频一定要分两路采再混
- 系统声 + 麦分开采，自己加 AGC / NS / AEC
- SCK 和 desktopCapturer 都不自带回声消除

### 4. 首帧延迟基线参考
- Mac SCK 裸采：**25–40 ms**
- Linux PipeWire：视 compositor 而定
- X11 + x264 软编在 30 fps 上 CPU 可飙到 **70%+**，高分辨率务必硬编

### 5. 跨端框架选型
- **Electron** → `desktopCapturer`
- **Flutter / Qt** → `libyzv` / GStreamer Rust 绑定
- **不要**在 Wayland 上试图自己绕开 portal——会被 compositor 返回黑帧

---

> **提示**：以上方案可根据具体场景（自研 SDK 嵌入产品 / 内部演示直播链路 / 双向远程控制）进一步展开为代码骨架和依赖清单。
