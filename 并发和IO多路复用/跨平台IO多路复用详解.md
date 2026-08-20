# 跨平台 IO 多路复用技术详解

> 本文系统梳理 IO 多路复用的核心概念、各操作系统原生机制、跨平台抽象思路，并给出可运行的跨平台示例代码与主流开源库选型建议。

---

## 一、IO 多路复用基础概念

### 1.1 定义
IO 多路复用（I/O Multiplexing）是一种**同步 IO 模型**：单个线程同时监视多个文件描述符（File Descriptor，FD）或套接字句柄，一旦其中某个或某些描述符就绪（可读 / 可写 / 异常），内核便通知应用程序进行相应处理。

其本质是：**用一次阻塞等待，换取对多个 IO 通道的并发监听能力**。

### 1.2 为什么需要它
- 传统 `read()` / `accept()` 是阻塞的，一个线程只能服务一个连接；
- 多线程 / 多进程模型在连接数达到上万时，上下文切换、栈内存、锁竞争开销急剧上升；
- IO 多路复用让单线程即可管理数万连接，是 Reactor 模式、高性能网络库（Nginx、Redis、Netty、libuv）的底层基石。

### 1.3 典型工作流程
1. 应用向内核注册一组待监听的 FD 及关心的事件（读 / 写 / 异常）；
2. 调用 `select / poll / epoll_wait / kevent / GetQueuedCompletionStatus` 等接口阻塞等待；
3. 内核返回就绪 FD 列表；
4. 应用遍历就绪列表，对每个 FD 执行非阻塞读写；
5. 处理完毕后重新注册（或保持注册），回到第 2 步循环。

---

## 二、各平台原生 IO 多路复用机制

不同操作系统提供了各自的原语，能力与性能差异巨大。跨平台库的核心工作，就是把这些差异封装成统一接口。

### 2.1 机制总览

| 机制 | 平台 | 类型 | 监听上限 | 就绪通知方式 | 典型性能 |
|------|------|------|----------|--------------|----------|
| `select` | POSIX 全平台（含 Windows） | 水平触发 | 通常 1024（FD_SETSIZE） | 每次返回全部集合，需自行遍历 | 低，O(N) |
| `poll` | POSIX（不含 Windows） | 水平触发 | 无硬上限（受内存限制） | 返回就绪数量，需遍历 pollfd 数组 | 中，O(N) |
| `epoll` | Linux 2.6+ | 水平 / 边缘触发 | 无硬上限 | 仅返回就绪 FD，红黑树 + 就绪链表 | 高，O(就绪数) |
| `kqueue` | FreeBSD / macOS / iOS | 水平 / 边缘触发 | 无硬上限 | 仅返回就绪事件，统一事件队列 | 高 |
| `IOCP`（I/O Completion Port） | Windows | 异步完成通知 | 无硬上限 | 提交异步 IO，完成后入队 | 极高（异步模型） |
| `/dev/poll` | Solaris | 轮询设备 | 无硬上限 | 写入监听集合，读取就绪列表 | 中高 |
| Event Ports | Solaris 10+ | 事件端口 | 无硬上限 | 端口事件通知 | 高 |

### 2.2 select —— 最古老但最通用
- 接口：`select(nfds, readfds, writefds, exceptfds, timeout)`
- 缺点：
  - FD 集合用位图表示，大小受 `FD_SETSIZE`（通常 1024）限制；
  - 每次调用都要把集合从用户态拷贝到内核态，返回后再拷贝回来；
  - 返回的是"全部集合"，应用必须遍历所有 FD 才能找出就绪的，O(N)；
  - 集合会被内核修改，每次调用前必须重新初始化。
- 优点：**几乎所有平台都支持**，是跨平台兜底方案。

### 2.3 poll —— select 的改进版
- 接口：`poll(struct pollfd *fds, nfds_t nfds, int timeout)`
- 改进：
  - 用 `pollfd` 数组代替位图，无 1024 上限；
  - 输入（events）与输出（revents）分离，不需要每次重建。
- 仍存在：每次调用都要把整个数组在用户态 / 内核态间拷贝，返回后仍需遍历全部 FD 判断 `revents`，O(N)。
- Windows **不支持** poll（WinSock 有 `WSAPoll`，但实现有 bug，不推荐）。

### 2.4 epoll —— Linux 高性能方案
- 核心接口：
  - `epoll_create1(flags)`：创建 epoll 实例（内核中的红黑树 + 就绪链表）；
  - `epoll_ctl(epfd, op, fd, event)`：增 / 删 / 改监听 FD，O(log N)；
  - `epoll_wait(epfd, events, maxevents, timeout)`：阻塞等待，仅返回就绪 FD。
- 关键优势：
  - **FD 集合常驻内核**，不需要每次调用都拷贝；
  - **只返回就绪 FD**，复杂度 O(就绪数)，与总连接数无关；
  - 支持 **ET（Edge Triggered，边缘触发）**，配合非阻塞 IO 可大幅减少系统调用次数。
- 注意：epoll 是 Linux 独有的，不可移植。

### 2.5 kqueue —— BSD / macOS 方案
- 接口：`kqueue()` 创建，`kevent(kq, changelist, nchanges, eventlist, nevents, timeout)` 同时完成注册与等待。
- 特点：
  - 统一的事件接口，不仅能监听 socket，还能监听文件、进程、信号、定时器、AIO 等；
  - 支持 EV_CLEAR（边缘触发语义）；
  - 性能与 epoll 同量级。
- macOS / iOS 上的 GCD（Grand Central Dispatch）底层也基于 kqueue。

### 2.6 IOCP —— Windows 的异步完成端口
IOCP 与前面几种**本质不同**：它不是"就绪通知"模型，而是"**异步完成通知**"模型。

- 工作方式：
  1. 应用把一个异步 IO 请求（`WSARecv` / `WSASend` / `AcceptEx`）提交给 IOCP；
  2. 内核在后台完成 IO，完成后把一个"完成包"（OVERLAPPED 结构）放入完成端口队列；
  3. 应用调用 `GetQueuedCompletionStatus` 取出完成包，处理数据。
- 优势：
  - 真正的异步 IO，数据直接由内核拷贝到用户缓冲区，应用拿到时数据已就绪；
  - 可绑定线程池，自动管理并发线程数；
  - Windows 平台性能最高的网络模型。
- 跨平台难点：IOCP 的"提交-完成"语义与 epoll/kqueue 的"注册-就绪"语义不同，封装时需要做模型转换（Proactor vs Reactor）。

---

## 三、跨平台抽象思路

### 3.1 两种封装策略

**策略 A：统一为 Reactor（就绪通知）模型**
- 把 IOCP 也模拟成"就绪通知"：内部提交一个零字节 `WSARecv`（或用 `AcceptEx`），完成时视为"可读就绪"，再由用户调用真正的 `recv`。
- 代表：libuv、libevent、boost::asio。
- 优点：上层 API 统一，跨平台逻辑一致。
- 缺点：在 Windows 上没有完全发挥 IOCP 的异步优势（多了一次系统调用）。

**策略 B：统一为 Proactor（异步完成）模型**
- 在 Linux/macOS 上用用户态线程池 + 非阻塞 IO 模拟异步完成。
- 代表：ACE（POCO 也偏 Proactor）、.NET 的 SocketAsyncEventArgs。
- 优点：Windows 上性能最优。
- 缺点：类 Unix 平台模拟开销大，复杂度高。

**主流选择：策略 A（Reactor 统一）**，因为类 Unix 平台占服务器市场绝大多数，且 Reactor 模型更简单直观。

### 3.2 统一事件循环的核心抽象

```
┌─────────────────────────────────────────┐
│              应用层（用户代码）            │
│   on_read / on_write / on_close 回调     │
├─────────────────────────────────────────┤
│         跨平台抽象层（Event Loop）         │
│  - io_watcher（监听 FD + 事件 + 回调）    │
│  - timer_watcher（定时器）                │
│  - async_watcher（线程间唤醒）             │
│  - run() / stop()                        │
├─────────────────────────────────────────┤
│  Linux epoll │ macOS kqueue │ Windows IOCP │
│  (兜底 select)                             │
└─────────────────────────────────────────┘
```

关键抽象点：
1. **事件循环（Event Loop）**：每个线程一个，驱动所有 IO；
2. **IO 观察者（IO Watcher）**：绑定一个 FD + 关心的事件（读/写）+ 回调；
3. **回调驱动**：就绪时由 loop 调用用户回调，用户在回调中做非阻塞读写；
4. **非阻塞 IO 强制**：所有被监听的 FD 必须设为非阻塞，否则 ET 模式或单次回调中可能阻塞整个 loop。

---

## 四、跨平台示例代码

### 4.1 示例一：使用 libuv 实现跨平台 TCP Echo Server（推荐）

libuv 是 Node.js 的底层事件库，原生跨平台（Linux epoll / macOS kqueue / Windows IOCP / SunOS event ports），API 简洁，是学习跨平台 IO 多路复用的最佳范例。

```c
/* echo_server.c —— 跨平台 TCP Echo Server，基于 libuv
 * 编译：
 *   Linux/macOS: gcc echo_server.c -o echo_server -luv
 *   Windows (MSVC): cl echo_server.c /I<libuv include> <libuv.lib> ws2_32.lib
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#define DEFAULT_PORT 7000
#define BUF_SIZE 1024

/* 每个连接的私有数据 */
typedef struct {
    uv_tcp_t handle;       /* TCP 句柄，必须放在第一个字段，便于类型转换 */
    char buf[BUF_SIZE];    /* 读缓冲区 */
} client_t;

/* 分配缓冲区的回调（libuv 在读之前调用） */
static void alloc_cb(uv_handle_t *handle, size_t suggested_size, uv_buf_t *buf) {
    client_t *client = (client_t *)handle->data;
    buf->base = client->buf;
    buf->len = BUF_SIZE;
}

/* 写完成回调 */
static void write_cb(uv_write_t *req, int status) {
    if (status) {
        fprintf(stderr, "Write error: %s\n", uv_strerror(status));
    }
    free(req);  /* 释放 write 请求对象 */
}

/* 读回调：有数据可读时被 libuv 调用 */
static void read_cb(uv_stream_t *stream, ssize_t nread, const uv_buf_t *buf) {
    if (nread > 0) {
        /* 收到数据，原样写回（echo） */
        uv_write_t *req = (uv_write_t *)malloc(sizeof(uv_write_t));
        uv_buf_t wrbuf = uv_buf_init(buf->base, nread);
        uv_write(req, stream, &wrbuf, 1, write_cb);
    } else if (nread < 0) {
        /* 对端关闭或出错，关闭连接 */
        if (nread != UV_EOF) {
            fprintf(stderr, "Read error: %s\n", uv_strerror((int)nread));
        }
        uv_close((uv_handle_t *)stream, (uv_close_cb)free);
    }
    /* nread == 0 时无需处理（libuv 会继续读） */
}

/* 新连接回调：有客户端连接时被 libuv 调用 */
static void connection_cb(uv_stream_t *server, int status) {
    if (status < 0) {
        fprintf(stderr, "Connection error: %s\n", uv_strerror(status));
        return;
    }

    client_t *client = (client_t *)malloc(sizeof(client_t));
    uv_tcp_init(server->loop, &client->handle);
    client->handle.data = client;  /* 把私有数据挂到 handle 上 */

    if (uv_accept(server, (uv_stream_t *)&client->handle) == 0) {
        /* 开始读，注册读事件到事件循环 */
        uv_read_start((uv_stream_t *)&client->handle, alloc_cb, read_cb);
    } else {
        uv_close((uv_handle_t *)&client->handle, (uv_close_cb)free);
    }
}

int main() {
    uv_loop_t *loop = uv_default_loop();

    uv_tcp_t server;
    uv_tcp_init(loop, &server);

    struct sockaddr_in addr;
    uv_ip4_addr("0.0.0.0", DEFAULT_PORT, &addr);

    uv_tcp_bind(&server, (const struct sockaddr *)&addr, 0);
    int r = uv_listen((uv_stream_t *)&server, 128, connection_cb);
    if (r) {
        fprintf(stderr, "Listen error: %s\n", uv_strerror(r));
        return 1;
    }

    printf("Echo server listening on port %d (libuv event loop)\n", DEFAULT_PORT);
    return uv_run(loop, UV_RUN_DEFAULT);
}
```

**跨平台要点说明：**
- 同一份代码在 Linux（epoll）、macOS（kqueue）、Windows（IOCP）上均可编译运行，libuv 内部自动选择最优后端；
- `uv_read_start` 注册读事件，`uv_write` 提交写请求，用户完全不接触 `epoll_ctl` / `kevent` / `IOCP`；
- libuv 在 Windows 上采用"Reactor 模拟"策略：内部用 IOCP 完成异步操作，对外暴露统一的回调接口。

### 4.2 示例二：手写极简跨平台抽象层（C 语言）

为了直观理解跨平台封装原理，下面给出一个**极简**的统一事件循环骨架，分别用 `#ifdef` 选择 epoll / kqueue / select 后端（IOCP 因模型差异较大，此处不展开，实际项目请直接用 libuv）。

```c
/* mini_loop.h —— 极简跨平台事件循环抽象 */
#ifndef MINI_LOOP_H
#define MINI_LOOP_H

#include <stdint.h>

typedef void (*io_cb)(int fd, int events, void *data);

typedef struct {
    int fd;
    int events;       /* 1=读, 2=写, 3=读写 */
    io_cb cb;
    void *data;
} io_watcher_t;

/* 创建事件循环 */
void *loop_create(void);
/* 销毁事件循环 */
void loop_destroy(void *loop);
/* 注册/更新 IO 监听 */
int loop_add_io(void *loop, io_watcher_t *w);
/* 移除 IO 监听 */
int loop_remove_io(void *loop, io_watcher_t *w);
/* 运行事件循环，超时毫秒（-1 表示永久阻塞） */
int loop_run(void *loop, int timeout_ms);

#endif
```

```c
/* mini_loop.c —— 跨平台实现（epoll / kqueue / select 三后端） */
#include "mini_loop.h"
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#if defined(__linux__)
    #include <sys/epoll.h>
    #define BACKEND_EPOLL
#elif defined(__APPLE__) || defined(__FreeBSD__)
    #include <sys/event.h>
    #include <sys/types.h>
    #include <unistd.h>
    #define BACKEND_KQUEUE
#else
    #include <sys/select.h>
    #include <unistd.h>
    #define BACKEND_SELECT
#endif

#define MAX_EVENTS 1024

typedef struct {
    int backend_fd;              /* epoll fd / kqueue fd / 未使用 */
    io_watcher_t *watchers[FD_SETSIZE];  /* select 后端用，其他后端也保留便于查找 */
} loop_t;

void *loop_create(void) {
    loop_t *l = (loop_t *)calloc(1, sizeof(loop_t));
#ifdef BACKEND_EPOLL
    l->backend_fd = epoll_create1(0);
#elif defined(BACKEND_KQUEUE)
    l->backend_fd = kqueue();
#else
    l->backend_fd = -1;
#endif
    return l;
}

void loop_destroy(void *loop) {
    loop_t *l = (loop_t *)loop;
    if (l->backend_fd >= 0) close(l->backend_fd);
    free(l);
}

int loop_add_io(void *loop, io_watcher_t *w) {
    loop_t *l = (loop_t *)loop;
    if (w->fd < 0 || w->fd >= FD_SETSIZE) return -1;
    l->watchers[w->fd] = w;

#ifdef BACKEND_EPOLL
    struct epoll_event ev = {0};
    ev.events = (w->events & 1 ? EPOLLIN : 0) | (w->events & 2 ? EPOLLOUT : 0);
    ev.data.ptr = w;
    return epoll_ctl(l->backend_fd, EPOLL_CTL_ADD, w->fd, &ev);
#elif defined(BACKEND_KQUEUE)
    struct kevent changes[2];
    int n = 0;
    if (w->events & 1) EV_SET(&changes[n++], w->fd, EVFILT_READ, EV_ADD, 0, 0, w);
    if (w->events & 2) EV_SET(&changes[n++], w->fd, EVFILT_WRITE, EV_ADD, 0, 0, w);
    return kevent(l->backend_fd, changes, n, NULL, 0, NULL);
#else
    return 0;  /* select 后端在 loop_run 时动态构建 fd_set */
#endif
}

int loop_remove_io(void *loop, io_watcher_t *w) {
    loop_t *l = (loop_t *)loop;
    if (w->fd < 0 || w->fd >= FD_SETSIZE) return -1;

#ifdef BACKEND_EPOLL
    epoll_ctl(l->backend_fd, EPOLL_CTL_DEL, w->fd, NULL);
#elif defined(BACKEND_KQUEUE)
    struct kevent changes[2];
    int n = 0;
    if (w->events & 1) EV_SET(&changes[n++], w->fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
    if (w->events & 2) EV_SET(&changes[n++], w->fd, EVFILT_WRITE, EV_DELETE, 0, 0, NULL);
    kevent(l->backend_fd, changes, n, NULL, 0, NULL);
#endif
    l->watchers[w->fd] = NULL;
    return 0;
}

int loop_run(void *loop, int timeout_ms) {
    loop_t *l = (loop_t *)loop;

#ifdef BACKEND_EPOLL
    struct epoll_event events[MAX_EVENTS];
    int n = epoll_wait(l->backend_fd, events, MAX_EVENTS, timeout_ms);
    for (int i = 0; i < n; i++) {
        io_watcher_t *w = (io_watcher_t *)events[i].data.ptr;
        int ev = (events[i].events & EPOLLIN ? 1 : 0) | (events[i].events & EPOLLOUT ? 2 : 0);
        if (w && w->cb) w->cb(w->fd, ev, w->data);
    }
    return n;

#elif defined(BACKEND_KQUEUE)
    struct kevent events[MAX_EVENTS];
    struct timespec ts = { timeout_ms / 1000, (timeout_ms % 1000) * 1000000L };
    struct timespec *pts = (timeout_ms < 0) ? NULL : &ts;
    int n = kevent(l->backend_fd, NULL, 0, events, MAX_EVENTS, pts);
    for (int i = 0; i < n; i++) {
        io_watcher_t *w = (io_watcher_t *)events[i].udata;
        int ev = (events[i].filter == EVFILT_READ ? 1 : 2);
        if (w && w->cb) w->cb(w->fd, ev, w->data);
    }
    return n;

#else
    fd_set rfds, wfds;
    FD_ZERO(&rfds); FD_ZERO(&wfds);
    int maxfd = -1;
    for (int i = 0; i < FD_SETSIZE; i++) {
        if (l->watchers[i]) {
            if (l->watchers[i]->events & 1) FD_SET(i, &rfds);
            if (l->watchers[i]->events & 2) FD_SET(i, &wfds);
            if (i > maxfd) maxfd = i;
        }
    }
    struct timeval tv = { timeout_ms / 1000, (timeout_ms % 1000) * 1000 };
    struct timeval *ptv = (timeout_ms < 0) ? NULL : &tv;
    int n = select(maxfd + 1, &rfds, &wfds, NULL, ptv);
    if (n > 0) {
        for (int i = 0; i <= maxfd; i++) {
            io_watcher_t *w = l->watchers[i];
            if (!w) continue;
            int ev = (FD_ISSET(i, &rfds) ? 1 : 0) | (FD_ISSET(i, &wfds) ? 2 : 0);
            if (ev && w->cb) w->cb(i, ev, w->data);
        }
    }
    return n;
#endif
}
```

**使用示例（TCP 回显的读回调骨架）：**

```c
#include "mini_loop.h"
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>

static void on_read(int fd, int events, void *data) {
    char buf[1024];
    ssize_t n = recv(fd, buf, sizeof(buf), 0);
    if (n > 0) {
        send(fd, buf, n, 0);  /* echo */
    } else if (n == 0) {
        close(fd);  /* 对端关闭，实际应从 loop 中移除 */
    }
}

int main(void) {
    void *loop = loop_create();
    /* ... 创建 listen socket、accept、设置非阻塞 ... */
    /* io_watcher_t w = { .fd = client_fd, .events = 1, .cb = on_read };
       loop_add_io(loop, &w);
       while (1) loop_run(loop, -1); */
    loop_destroy(loop);
    return 0;
}
```

> 这个极简版本仅用于演示跨平台封装原理。生产环境请使用下方成熟开源库，它们还处理了 ET 模式、信号、定时器、线程安全、异步 DNS、文件 IO、子进程等大量边界问题。

---

## 五、主流跨平台开源库

### 5.1 综合对比

| 库 | 语言 | 后端支持 | 模型 | 特点 | 适用场景 |
|----|------|----------|------|------|----------|
| **libuv** | C | epoll / kqueue / IOCP / event ports / select | Reactor | Node.js 底层，API 简洁，功能全面，活跃维护 | 跨平台服务端、工具链、Node.js 原生模块 |
| **libevent** | C | epoll / kqueue / IOCP / poll / select | Reactor | 老牌稳定，内存占用小，有 bufferevent 高层抽象 | 嵌入式、资源受限环境、遗留系统 |
| **libev** | C | epoll / kqueue / poll / select（**无 Windows 原生支持**） | Reactor | 极简高性能，API 清晰，但作者已停止维护 | Linux/macOS 高性能服务端 |
| **Boost.Asio** | C++ | epoll / kqueue / IOCP / select | Reactor + Proactor | C++ 标准网络库候选（`std::execution` 方向），异步链式调用 | C++ 高性能网络、游戏服务端 |
| **POCO** | C++ | epoll / kqueue / IOCP / select | Reactor | 全功能应用框架（网络+数据库+XML+JSON） | C++ 企业级应用 |
| **ACE** | C++ | 全平台 | Proactor 为主 | 最老牌，功能庞大但学习曲线陡峭 | 电信、军工、遗留 C++ 系统 |
| **Netty** | Java | Java NIO（底层 epoll/kqueue/IOCP） | Reactor | Java 生态事实标准，高性能，协议栈丰富 | Java 后端、RPC、网关、消息中间件 |
| **Tokio** | Rust | epoll / kqueue / IOCP（via mio） | Reactor | Rust 异步运行时，零成本抽象，内存安全 | Rust 高性能服务端、工具链 |
| **asyncio** | Python | epoll / kqueue / IOCP（ProactorEventLoop） | Reactor + Proactor | Python 标准库，`async/await` 语法 | Python 异步服务、爬虫、脚本 |
| **Node.js (libuv)** | JS | libuv 全平台 | Reactor | 事件驱动单线程，生态庞大 | Web 后端、全栈、工具链 |
| **Go runtime** | Go | 自研 netpoll（epoll/kqueue）+  goroutine | 同步语义+多路复用 | 用户态 goroutine 调度，写同步代码享异步性能 | 云原生、微服务、高并发服务 |

### 5.2 重点库详解

#### libuv（最推荐学习与使用）
- **官网**：https://libuv.org
- **源码**：https://github.com/libuv/libuv
- **核心能力**：TCP/UDP、命名管道、TTY、文件 IO（线程池模拟异步）、定时器、信号、子进程、线程池、异步句柄、线程间通信。
- **设计哲学**：统一事件循环，所有 IO 都是非阻塞 + 回调，Windows 上用 IOCP 模拟 Reactor。
- **典型用户**：Node.js、Rust 的 `mio`（早期）、Julia、Neovim、CMake 的 CTest。

#### libevent
- **官网**：https://libevent.org
- **源码**：https://github.com/libevent/libevent
- **特点**：
  - 2002 年诞生，历史最悠久，稳定性经过大量验证；
  - 提供 `bufferevent` 高层缓冲 IO，简化读写；
  - 支持 HTTP、DNS、RPC 等协议层（`evhttp`）；
  - 内存占用比 libuv 小，适合嵌入式。
- **典型用户**：Memcached、Tor、Chromium（部分）、tmux。

#### Boost.Asio
- **官网**：https://www.boost.org/doc/libs/release/libs/asio/
- **源码**：https://github.com/chriskohlhoff/asio
- **特点**：
  - C++ 模板库，header-only（部分）；
  - 支持 `async_read` / `async_write` 链式异步调用；
  - 正在被标准化为 C++ 标准网络库（`std::net`，目前 TS 阶段）；
  - Windows 上原生使用 IOCP 异步模型，性能最优。
- **典型用户**：MySQL Connector/C++、ROS2（部分）、大量 C++ 网络项目。

#### Netty（Java 生态首选）
- **官网**：https://netty.io
- **源码**：https://github.com/netty/netty
- **特点**：
  - Java NIO 的封装与增强，提供 `ChannelPipeline` + `ChannelHandler` 责任链模式；
  - 内置 HTTP/2、WebSocket、Protobuf、Redis、MQTT 等大量编解码器；
  - 自带内存池（`PooledByteBufAllocator`）、零拷贝、流量整形；
  - 可通过 `EpollEventLoopGroup` / `KQueueEventLoopGroup` 使用原生 transport，性能优于 JDK NIO。
- **典型用户**：Apache Dubbo、RocketMQ、Spark、Cassandra、Elasticsearch、gRPC-Java。

#### Tokio（Rust 生态首选）
- **官网**：https://tokio.rs
- **源码**：https://github.com/tokio-rs/tokio
- **特点**：
  - Rust 异步运行时，基于 `mio`（跨平台 IO 抽象）；
  - 提供 `tokio::net::TcpListener` 等异步 IO 原语；
  - 多线程工作窃取调度器，`async/await` 零成本抽象；
  - 内存安全，无数据竞争。
- **典型用户**：Deno、TiKV、Linkerd2-proxy、大量 Rust 云原生项目。

### 5.3 选型建议

| 你的场景 | 推荐库 |
|----------|--------|
| C 语言，需要全平台（含 Windows），功能全面 | **libuv** |
| C 语言，资源受限 / 嵌入式 / 只需 Linux | **libevent** 或 **libev** |
| C++，追求现代异步语法 / 未来标准化 | **Boost.Asio** |
| C++，需要全功能企业框架（数据库+网络+序列化） | **POCO** |
| Java / JVM 语言 | **Netty** |
| Rust | **Tokio** |
| Python | 标准库 **asyncio**（高性能可加 `uvloop`） |
| JavaScript / TypeScript | **Node.js**（内置 libuv） |
| Go | 直接用标准库 `net`（runtime 自动多路复用） |
| 只想学习原理，不引入重依赖 | 自己基于 `epoll` / `kqueue` 封装，或阅读 libuv 源码 |

---

## 六、关键注意事项与最佳实践

1. **非阻塞是前提**：所有注册到事件循环的 FD 必须设置为非阻塞（`O_NONBLOCK` / `FIONBIO`），否则一次慢 IO 会阻塞整个事件循环，所有连接全部卡住。

2. **ET 模式必须读到 EAGAIN**：使用 epoll ET（边缘触发）时，可读事件只在状态变化时触发一次，必须在回调中循环 `recv` 直到返回 `EAGAIN`，否则剩余数据不会再触发事件，造成"假死"。

3. **写事件通常是水平触发 + 按需注册**：写缓冲区大部分时间都是可写的，如果一直注册写事件会导致事件循环 100% CPU 空转。正确做法是：只有当 `send` 返回 `EAGAIN`（写缓冲区满）时才注册写事件，写完后立即移除。

4. **避免在回调中做阻塞操作**：事件循环是单线程的，回调里执行阻塞调用（同步 DNS、文件 IO、sleep、锁等待）会拖慢所有连接。文件 IO 应丢到线程池（libuv 内置），DNS 用异步解析。

5. **注意 FD 复用问题**：关闭 FD 后必须先从事件循环中移除，再 `close`。否则新连接复用了同一个 FD 号，旧的监听还在，会导致事件错乱。

6. **Windows 上的特殊处理**：
   - WinSock 的 `select` 只能用于 socket，不能用于文件 / 管道；
   - `WSAPoll` 在旧版 Windows 上有 bug，尽量用 IOCP 或 libuv；
   - IOCP 的完成包可能在任意线程出队，需要注意线程安全。

7. **连接数与内存**：epoll/kqueue 本身支持数十万连接，但每个连接的应用层缓冲区、TCP 缓冲区（`SO_RCVBUF` / `SO_SNDBUF`）、内核 socket 结构都会占用内存。百万连接通常需要调大 `ulimit -n`、`net.core.somaxconn`、`vm.max_map_count` 等内核参数。

8. **多线程模型**：常见模式是"one loop per thread"（每个线程一个独立事件循环），如 Netty、muduo。主线程 accept 后把连接轮询分配给子线程的 loop，避免锁竞争。不要多线程共享同一个 epoll 实例（除非非常清楚自己在做什么）。

---

## 七、参考资料

- libuv 官方文档：https://docs.libuv.org
- libevent 官方书籍（《libevent Book》）：https://libevent.org/libevent-book/
- Boost.Asio 文档：https://www.boost.org/doc/libs/release/libs/asio/
- Netty 官方指南：https://netty.io/wiki/user-guide-for-4.x.html
- 《UNIX 网络编程 卷1：套接字联网 API》第 6 章（I/O 多路复用）
- 《Linux 高性能服务器编程》（游双）—— epoll / Reactor / Proactor 详解
- Nginx 源码 `src/event/modules/ngx_epoll_module.c`、`ngx_kqueue_module.c`、`ngx_select_module.c`
- Redis 源码 `src/ae.c`（极简事件循环，是学习 epoll/kqueue/select 封装的绝佳范例）
