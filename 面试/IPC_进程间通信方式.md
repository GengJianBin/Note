# 进程间通信（IPC）方式详解

> 本文系统梳理 **7 种经典进程间通信（IPC）方式**：匿名管道、命名管道、消息队列、共享内存、信号量、信号、事件（Event），涵盖概念、差别、用法、适用场景、优缺点及跨平台 API。

---

## 一、总览对照表

| IPC 方式 | 数据形式 | 是否带边界 | 是否支持无亲缘进程 | 速度 | 典型用途 |
|---------|---------|-----------|------------------|------|---------|
| 匿名管道 Pipe | 字节流 | ❌ | ❌（仅父子） | 中 | Shell、父子通信 |
| 命名管道 FIFO | 字节流 | ❌ | ✅ | 中 | 本地进程简单通信 |
| 消息队列 Message Queue | 消息（类型+数据） | ✅ | ✅ | 中 | 结构化异步通信 |
| 共享内存 Shared Memory | 内存块 | ❌ | ✅ | **最快** | 大数据、高频交换 |
| 信号量 Semaphore | 计数器/锁 | — | ✅ | 快 | 同步、互斥 |
| 信号 Signal | 事件编号 | — | ✅ | 快 | 通知、控制 |
| 事件 Event | 状态标志（有信号/无信号） | — | ✅ | 快 | 进程/线程同步等待 |

---

## 二、匿名管道（Pipe）

### 2.1 概念与差别
- **半双工**字节流通信机制
- 数据在内核缓冲区中流动，**无消息边界**
- **只能用于有亲缘关系的进程**（父子 / 兄弟进程）
- 生命周期随进程结束而终止

### 2.2 用法

**C 代码示例：**
```c
int fd[2];
pipe(fd);
// fd[0] 读端，fd[1] 写端

// 父进程写，子进程读（fork 之后关闭不需要的端）
write(fd[1], "hello", 5);
read(fd[0], buf, 5);
```

**Shell 示例：**
```bash
ls | grep .c
```

### 2.3 适用场景
- 父子进程间一次性或流式数据传输
- Shell 管道实现
- 简单的命令链式调用

### 2.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 使用简单、接口稳定 | 无消息边界，需自行分包 |
| 内核自动同步（读空/写满阻塞） | 只能用于亲缘进程 |
|  | 单向通信（双向需两个管道） |

### 2.5 平台 API

| 平台 | API |
|------|-----|
| Linux / Unix | `pipe()` |
| macOS | `pipe()` |
| Windows | 无直接等价（可用匿名管道 `CreatePipe` 模拟） |

---

## 三、命名管道（FIFO）

### 3.1 概念与差别
- 匿名管道 + **文件系统路径**
- 以特殊文件形式存在于文件系统中
- **无亲缘关系的进程也能通信**
- 打开时遵循"读端和写端都打开才通"的规则

### 3.2 用法

**C 代码示例：**
```c
// 创建
mkfifo("/tmp/myfifo", 0644);

// 进程 A（写）
int fd = open("/tmp/myfifo", O_WRONLY);
write(fd, "hello fifo", 10);

// 进程 B（读）
int fd = open("/tmp/myfifo", O_RDONLY);
read(fd, buf, 10);
```

**Shell 示例：**
```bash
# 终端 1
mkfifo /tmp/myfifo
echo "hello" > /tmp/myfifo

# 终端 2
cat < /tmp/myfifo
```

### 3.3 适用场景
- 两个独立本地进程之间的通信
- 替代临时 Socket 的简单方案
- 脚本之间的数据传递

### 3.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 使用简单，兼容 Shell | 仍是字节流，无消息边界 |
| 支持无亲缘进程 | 性能一般 |
|  | 不适合复杂协议 |

### 3.5 平台 API

| 平台 | API |
|------|-----|
| Linux / Unix | `mkfifo()`、`open()` |
| macOS | `mkfifo()`、`open()` |
| Windows | `CreateNamedPipe()`（语义不同，更接近本地 Socket） |

---

## 四、消息队列（Message Queue）

### 4.1 概念与差别
- 内核维护的**消息链表**，每条消息包含**类型 + 数据**
- **有消息边界**，支持按类型读取
- 支持**异步通信**
- 生命周期独立于进程（除非显式删除或系统重启）
- 常见两套接口：**System V** 和 **POSIX**

### 4.2 用法

**System V 示例：**
```c
// 创建/获取队列
int msqid = msgget(key, IPC_CREAT | 0666);

// 发送消息
struct msgbuf {
    long mtype;
    char mtext[100];
};
struct msgbuf msg;
msg.mtype = 1;
strcpy(msg.mtext, "hello queue");
msgsnd(msqid, &msg, strlen(msg.mtext) + 1, 0);

// 接收指定类型消息
msgrcv(msqid, &msg, 100, 1, 0);
```

**POSIX 示例：**
```c
mqd_t mq = mq_open("/myqueue", O_CREAT | O_RDWR, 0644, NULL);
mq_send(mq, "hello", 5, 0);
mq_receive(mq, buf, 100, NULL);
```

### 4.3 适用场景
- 多类型消息分发
- 生产者 / 消费者模型
- 需要结构化、按类型分发消息的场景
- 不想自己处理字节流分包的情况

### 4.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 有消息边界，按类型收发 | 内核拷贝，比共享内存慢 |
| 支持异步、多对多通信 | 单条消息大小受限 |
| 生命周期独立于进程 | System V 接口偏老 |
|  | 调试不够直观 |

### 4.5 平台 API

| 平台 | API | 支持情况 |
|------|-----|---------|
| Linux | System V：`msgget/msgsnd/msgrcv`<br>POSIX：`mq_open/mq_send/mq_receive` | 两套均支持 |
| macOS | POSIX mq | 支持较好 |
| Windows | 无原生消息队列 | 需使用 MQ 中间件（如 MSMQ、RabbitMQ） |

---

## 五、共享内存（Shared Memory）

### 5.1 概念与差别
- **最快的 IPC 方式**：零拷贝，多个进程直接映射同一块物理内存
- 本身**不带同步机制**，必须配合信号量或互斥锁使用
- 数据写入后立即可被其他进程读取

### 5.2 用法

**System V 示例：**
```c
// 创建共享内存
int shmid = shmget(key, 4096, IPC_CREAT | 0666);

// 映射到进程地址空间
void *addr = shmat(shmid, NULL, 0);

// 直接读写内存
strcpy((char *)addr, "shared data");

// 解除映射
shmdt(addr);
```

**POSIX + mmap 示例：**
```c
int fd = shm_open("/myshm", O_CREAT | O_RDWR, 0644);
ftruncate(fd, 4096);
void *addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

// 直接读写
strcpy((char *)addr, "shared data");

munmap(addr, 4096);
```

### 5.3 适用场景
- 高频、大数据量交换（音视频帧、矩阵运算、缓存）
- 对性能极度敏感的系统
- 多进程共享配置/状态数据

### 5.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| **速度最快**，零拷贝 | 不带同步，必须配锁 |
| 无内核中转开销 | 容易出现竞态条件 |
| 适合大数据块 | 调试困难，易踩内存错误 |
|  | 生命周期管理需注意 |

### 5.5 平台 API

| 平台 | API |
|------|-----|
| Linux | System V：`shmget/shmat/shmdt`<br>POSIX：`shm_open + mmap` |
| macOS | `shm_open + mmap` |
| Windows | `CreateFileMapping()` + `MapViewOfFile()` |

---

## 六、信号量（Semaphore）

### 6.1 概念与差别
- **不用于传数据，专用于同步/互斥**
- 本质是一个内核计数器
- 支持 `P（wait）` 和 `V（post）` 操作
- 可用于**进程间**或**线程间**同步

### 6.2 用法

**System V 示例：**
```c
// 创建信号量集
int semid = semget(key, 1, IPC_CREAT | 0666);

// P 操作（减 1，获取资源）
struct sembuf p = {0, -1, 0};
semop(semid, &p, 1);

// 临界区操作...

// V 操作（加 1，释放资源）
struct sembuf v = {0, 1, 0};
semop(semid, &v, 1);
```

**POSIX 示例：**
```c
sem_t *sem = sem_open("/mysem", O_CREAT, 0644, 1);
sem_wait(sem);      // P 操作
// 临界区
sem_post(sem);      // V 操作
```

### 6.3 适用场景
- 共享内存的锁机制
- 生产者 / 消费者同步
- 资源计数与限流
- 多进程互斥访问临界资源

### 6.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 精确控制同步与互斥 | 不传输业务数据 |
| 支持进程级和线程级 | 使用不当易死锁 |
| 内核级保障 | 需配合其他 IPC 使用 |

### 6.5 平台 API

| 平台 | API |
|------|-----|
| Linux | System V：`semget/semop/semctl`<br>POSIX：`sem_init/sem_wait/sem_post` |
| macOS | POSIX semaphore |
| Windows | `CreateSemaphore()` + `WaitForSingleObject()` + `ReleaseSemaphore()` |

---

## 七、信号（Signal）

### 7.1 概念与差别
- **异步事件通知机制**，不是数据传输通道
- 内核或进程向目标进程发送一个信号编号
- 目标进程收到后**立即中断当前执行流**，跳转至信号处理函数
- 常见信号：`SIGKILL`、`SIGTERM`、`SIGINT`、`SIGCHLD`、`SIGUSR1/2`

### 7.2 用法

**C 代码示例：**
```c
#include <signal.h>
#include <stdio.h>

void handler(int sig) {
    printf("Received signal: %d\n", sig);
}

int main() {
    signal(SIGINT, handler);       // 注册处理函数
    // 或使用更推荐的 sigaction
    while (1) {
        pause();                   // 等待信号
    }
    return 0;
}
```

**发送信号：**
```c
kill(pid, SIGUSR1);               // 向指定进程发信号
raise(SIGTERM);                   // 向自己发信号
```

### 7.3 适用场景
- 进程启停控制（优雅退出、热重启）
- 子进程状态变化通知（`SIGCHLD`）
- 终端中断处理（Ctrl+C → `SIGINT`）
- 进程间轻量级事件通知

### 7.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 极轻量，系统级支持 | 不能携带复杂数据（仅信号编号） |
| 异步、实时性强 | 信号处理函数编写受限（异步安全） |
| 标准化程度高 | `SIGKILL`、`SIGSTOP` 不可捕获 |
|  | 信号可能丢失（标准信号不支持排队） |

### 7.5 平台 API

| 平台 | API |
|------|-----|
| Linux / Unix | `kill()`、`signal()`、`sigaction()`、`pause()` |
| macOS | 同 Linux |
| Windows | 无直接等价（可用 `RaiseException` 或控制台事件模拟） |

---

## 八、事件（Event）

### 8.1 概念与差别
- **内核对象**，用于**进程间或线程间同步等待**
- 只有两种状态：**有信号（signaled）** 和 **无信号（non-signaled）**
- 进程 A 等待事件 → 进程 B 触发事件 → A 被唤醒继续执行
- 分为**自动重置（auto-reset）** 和 **手动重置（manual-reset）** 两种模式
- **不传输数据**，仅用于"等某事发生"的同步语义
- Linux 上无原生 Event 对象，通常用 **`eventfd`** 或 **条件变量 + 共享内存** 实现

### 8.2 用法

**Linux — eventfd 示例：**
```c
#include <sys/eventfd.h>
#include <unistd.h>

// 进程 A（等待事件）
int efd = eventfd(0, EFD_SEMAPHORE);
uint64_t val;
read(efd, &val, sizeof(val));   // 阻塞等待，直到被写入

// 进程 B（触发事件）
int efd = eventfd(0, EFD_SEMAPHORE);
uint64_t val = 1;
write(efd, &val, sizeof(val));  // 写入后，等待方被唤醒
```

**Linux — pthread 条件变量（线程间）：**
```c
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;

// 等待方
pthread_mutex_lock(&mutex);
pthread_cond_wait(&cond, &mutex);   // 阻塞等待
pthread_mutex_unlock(&mutex);

// 触发方
pthread_mutex_lock(&mutex);
pthread_cond_signal(&cond);         // 唤醒一个等待者
pthread_mutex_unlock(&mutex);
```

**Windows — CreateEvent 示例：**
```c
// 创建手动重置事件（初始无信号）
HANDLE hEvent = CreateEvent(
    NULL,           // 安全属性
    TRUE,           // TRUE=手动重置，FALSE=自动重置
    FALSE,          // 初始状态：无信号
    L"MyEvent"      // 可选名称（跨进程需命名）
);

// 等待方（可跨进程，通过 OpenEvent 获取句柄）
WaitForSingleObject(hEvent, INFINITE);  // 阻塞等待

// 触发方
SetEvent(hEvent);                        // 设置为有信号，唤醒等待者
// 或 ResetEvent(hEvent);                // 手动重置为无信号
```

**Windows — 跨进程打开：**
```c
HANDLE hEvent = OpenEvent(EVENT_ALL_ACCESS, FALSE, L"MyEvent");
```

### 8.3 适用场景
- **一进程等另一进程完成某操作**（如初始化完成、数据就绪）
- 生产者/消费者模型中"数据已准备好"的通知
- 多进程启动编排（等所有进程就绪再开始）
- 线程池任务派发通知
- Windows 服务程序中的状态等待

### 8.4 优缺点

| ✅ 优点 | ❌ 缺点 |
|--------|--------|
| 语义清晰：只管"等/通知" | **不传输业务数据**，仅传递状态 |
| 内核级同步，可靠性高 | Linux 无原生 Event，需 eventfd 或模拟 |
| 支持跨进程和跨线程 | 自动重置事件易用错（可能丢失唤醒） |
| Windows 原生支持，使用简单 | 过度使用会导致"事件风暴"、逻辑复杂 |
| 可设置超时等待，不永久阻塞 | 调试时难以追踪事件状态 |

### 8.5 平台 API

| 平台 | 原生 API | 替代/补充方案 |
|------|---------|-------------|
| Linux | `eventfd()`（最贴近 Event 语义） | `pthread_cond_t`（线程间）、`signalfd`、`pipe` 模拟 |
| macOS | 无原生 Event | `pthread_cond_t`、`dispatch_semaphore`（GCD） |
| Windows | `CreateEvent()` / `OpenEvent()` / `SetEvent()` / `ResetEvent()` | `WaitForSingleObject()` / `WaitForMultipleObjects()` |

> 💡 **Linux vs Windows 对照**：
> - Windows 的 `CreateEvent` ≈ Linux 的 `eventfd` + `poll/epoll`
> - Windows 的 `SetEvent` ≈ 向 `eventfd` 写入一个值
> - Windows 的 `WaitForSingleObject` ≈ Linux 的 `read` 阻塞或 `epoll_wait`

---

## 九、跨平台 API 速查总表

| IPC 方式 | Linux / Unix | macOS | Windows |
|---------|-------------|-------|---------|
| 匿名管道 | `pipe()` | `pipe()` | `CreatePipe()` |
| 命名管道 | `mkfifo()` + `open()` | `mkfifo()` + `open()` | `CreateNamedPipe()` |
| 消息队列 | System V / POSIX mq | POSIX mq | 无（用 MQ 中间件） |
| 共享内存 | `shmget/mmap` | `shm_open + mmap` | `CreateFileMapping()` |
| 信号量 | System V / POSIX sem | POSIX sem | `CreateSemaphore()` |
| 信号 | `kill/sigaction` | `kill/sigaction` | 部分模拟 |
| 事件 Event | `eventfd()` / `pthread_cond_t` | `pthread_cond_t` / GCD | `CreateEvent()` / `SetEvent()` |
| Socket（补充） | BSD socket | BSD socket | Winsock |

> ⚠️ **注意**：Windows 的"命名管道" ≠ Unix FIFO，功能上更接近本地 Socket。

---

## 十、工程选型建议

| 需求 | 推荐方案 |
|------|---------|
| 父子进程、Shell 风格 | **匿名管道** |
| 本地两个独立程序 | **命名管道 / Unix Domain Socket** |
| 高性能、大数据量 | **共享内存 + 信号量** |
| 业务消息、解耦 | **消息队列 / MQ 中间件** |
| 启停 / 热加载 / 通知 | **信号** |
| 等待某进程完成初始化/就绪 | **事件 Event（或 eventfd）** |
| 跨机器通信 | **Socket / gRPC / Kafka** |

---

## 十一、核心要点总结

1. **Pipe/FIFO**：简单但能力弱，适合小数据流式传输
2. **Message Queue**：结构好、有边界，但性能不如共享内存
3. **Shared Memory**：速度之王，但必须自己解决同步问题
4. **Semaphore**：不传数据，只管同步，常配合共享内存使用
5. **Signal**：只通知不通信，适合控制流而非数据流
6. **Event**：等通知再行动，语义最清晰的"等待-唤醒"机制
7. **Socket**：最通用，可跨机，是分布式系统的基石

> 💡 **经验法则**：先判断"要传数据还是只通知" → 再判断"数据量大不大" → 最后决定用哪种 IPC。

---

*文档生成时间：2026-08-11*
