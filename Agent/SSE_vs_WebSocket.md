# SSE vs WebSocket 技术对比

SSE 和 WebSocket 都是用于**服务器向浏览器推送数据**的技术，但设计目标和使用场景差别很大。下面从原理、特性到选型给你一个清晰的对比。

---

## 一、核心概念

### 1. SSE（Server-Sent Events）

- **本质**：基于 HTTP 的**单向通信**（服务器 → 客户端）
- **协议**：普通 HTTP/HTTPS
- **规范**：HTML5 标准（`EventSource` API）

工作流程：

1. 浏览器通过 `EventSource` 发起 HTTP 请求
2. 服务器响应 `Content-Type: text/event-stream`
3. 连接**保持不关闭**，服务器持续推送文本数据流
4. 浏览器按事件解析并触发回调

示例（简化）：

```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: hello\n\n
data: world\n\n
```

JS 端：

```js
const es = new EventSource('/sse');
es.onmessage = e => console.log(e.data);
```

---

### 2. WebSocket

- **本质**：独立的**全双工通信协议**
- **协议**：`ws://` 或 `wss://`
- **握手后**：脱离 HTTP，双方随时互发数据

工作流程：

1. 客户端发起 HTTP 请求，带 `Upgrade: websocket`
2. 服务器返回 `101 Switching Protocols`
3. 之后就是持久的 TCP 双向通道

JS 端：

```js
const ws = new WebSocket('wss://example.com/ws');
ws.onmessage = e => console.log(e.data);
ws.send('hello');
```

---

## 二、对比总表

| 维度 | SSE | WebSocket |
|---|---|---|
| 通信方向 | 单向（服务器 → 客户端） | 全双工（双向） |
| 协议 | HTTP | WebSocket 独立协议 |
| 连接数 | 同域通常 6 个（受 HTTP 限制） | 理论上无限制 |
| 断线重连 | **原生支持**（自动重试） | 需手动实现 |
| 数据格式 | 文本（UTF‑8） | 文本 / 二进制 |
| 复杂度 | 非常简单 | 相对复杂 |
| 兼容性 | IE 不支持 | 现代浏览器全面支持 |
| 代理 / 防火墙 | 友好（走 HTTP） | 部分环境可能拦截 |
| 心跳机制 | 可选 | 通常需要 |
| 典型延迟 | 低 | 极低 |

---

## 三、各自适合什么场景？

### ✅ 适合用 SSE 的场景

- **服务器主动推送，客户端基本不发送**
- 实时通知 / 公告
- 股票行情、比分直播
- 日志流式输出
- 服务端事件广播

✅ 优点：

- 实现简单
- 天然支持断线重连
- 对现有 HTTP 基础设施友好

❌ 局限：

- 只能服务器推
- 不能发二进制
- 不适合高频双向通信

---

### ✅ 适合用 WebSocket 的场景

- **强实时 + 双向交互**
- 聊天室 / IM
- 在线协作（文档、白板）
- 多人游戏
- 实时交易系统
- 需要发二进制（音视频、文件）

✅ 优点：

- 真正的全双工
- 低延迟、高吞吐
- 支持二进制

❌ 局限：

- 实现和维护成本高
- 重连、心跳、鉴权都要自己处理
- 某些代理/防火墙支持不佳

---

## 四、常见组合用法（实际项目很常见）

### 1️⃣ SSE + 普通 HTTP

> 大多数后台管理系统的首选

- SSE：接收通知、日志、进度
- HTTP：提交表单、操作资源

### 2️⃣ WebSocket + REST API

> 主流实时系统架构

- WebSocket：实时消息、状态同步
- REST：业务操作、数据查询

### 3️⃣ WebSocket + SSE

- WebSocket：双向高频通信
- SSE：辅助通知、广播、降级方案

---

## 五、简单选型建议

| 需求 | 推荐 |
|---|---|
| 只要服务器推消息 | **SSE** |
| 需要双向实时通信 | **WebSocket** |
| 想省事、维护成本低 | **SSE** |
| 高并发、高频交互 | **WebSocket** |
| 老浏览器兼容 | **WebSocket（polyfill）** |
| 已有 HTTP 体系 | **SSE 更容易集成** |

---

## 六、一句话总结

> **SSE 是"增强版的长轮询"，WebSocket 是"真正的实时通道"。**

---

## 七、参考资料

- [MDN - Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [MDN - WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [RFC 6455 - The WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
- [HTML5 SSE Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)
