# 一、Cordis流程
## 1.1 插件基础定义
先明确定位：apply 是 Cordis 插件的标准入口函数，插件本质就是一个签名为 (ctx: Context) => Promise<() => void> 的函数。
```js
// 标准写法
export const apply = (ctx: Context): Promise<() => void> =>
  Promise.resolve(ctx.invariants.register(PACKAGE_NAME, install))

// install：真正的初始化逻辑
function install(ctx: Context) {
  // 在这里写业务、注册 effect、注册工具、监听事件
  ctx.effect(() => {
    const timer = setInterval(() => {}, 1000)
    return () => clearInterval(timer)
  })
}
```
## 1.2 从头到尾拆解从框架加载插件 → 初始化 → 运行 → 卸载全链路时序

### 1.2.1 阶段 1：框架触发插件加载
1. Cordis 扫描配置 / 插件列表，找到插件模块，导入得到 { apply }
2. 创建子 Fiber（隔离生命周期上下文），生成该插件专属的 ctx: Context
3. 调用 apply(ctx)，进入插件入口
### 1.2.2 阶段 2：执行 apply 内部逻辑
```ts
Promise.resolve(ctx.invariants.register(PACKAGE_NAME, install))
```
1. 执行 ctx.invariants.register(pkgName, installFn)
    -  invariants 做幂等校验：判断该包是否已经激活，防止重复安装
    -  如果未安装：内部执行 install(ctx)（真正跑你的初始化代码）
    -  在 install(ctx) 执行期间：所有 ctx.effect() 立刻执行初始化逻辑，并把 disposer 推入当前 Fiber 的清理栈
2. register 的返回值 = 整个插件的顶层 dispose 函数
3. Promise.resolve(顶层dispose) 把同步值包装成 Promise，满足插件异步签名
### 1.2.3 阶段 3：框架等待 Promise resolve
1. apply() 返回一个 Promise
2. Cordis await 这个 Promise
3. Promise resolve 的结果：插件全局卸载函数（root disposer）
4. 框架保存这个 root disposer，绑定到当前 Fiber 生命周期对象上  
👉 到此：插件加载完成，进入活跃状态（ACTIVE），业务开始运行
> 关键点区分：  
> install 执行时机：在 invariants.register 内部同步执行  
> ctx.effect 的副作用：install 执行时立即生效
### 1.2.4 阶段 4：插件运行期
插件正常工作：注册的工具、定时器、子进程、事件监听全部存活
- 你可以手动调用单个 effect 返回的 disposer，提前销毁局部资源
- Fiber 保持 ACTIVE，所有 effect 资源挂在 Fiber 的清理栈上
### 1.2.5 卸载 / 热重载 / 销毁流程（触发 root disposer）
触发时机：插件禁用、配置变更、进程关闭、热更新
1. 框架调用之前保存的顶层 root disposer
2. Fiber 进入 DISPOSING 状态
3. 框架逆序遍历 effect 清理栈（后进先出），逐个执行每一条 effect 的销毁.逻辑
   - 同步 disposer：直接执行
   - 异步 disposer：依次 await
4. 全部资源清理完毕 → Fiber 标记为 DISPOSED
5. 插件完全下线，不会残留定时器、子进程、端口占用

# 二、Context中的函数
## 2.1 Context.effect
- 注册一条「可逆副作用」，绑定到当前插件 Fiber 生命周期；插件卸载 / 热重载时，框架自动执行清理函数(这个清理函数就是**通过effect注册的函数的返回函数**)，杜绝资源泄漏。
- Context.effectd的返回值和注册函数的返回函数
  - effect自身的返回值：
    - 返回一个包装后的 disposable 清理函数（可安全重复调用，只会执行一次）
      - 你可以手动提前释放这个 effect：handle()
      - 内部做了防重复执行标记（disposed flag），多次调用只会执行一次真实销毁逻辑
    - 如果回调返回带 .dispose 的对象，返回的对象会被打上包装后的 .dispose 方法
    - 两者的差别在于清理资源的时机：一个是自动清理，另一个是手动清理
  - 通过effect注册的回调函数的返回值：在插件卸载或重载时执行
- Context.effectd的执行流程：
    - 立即运行回调，产生副作用（开定时器、连端口、spawn 子进程）
    - 捕获你返回的 disposer（清理函数）
    - 把这个 disposer 存入当前 Fiber 的清理栈（LIFO 后进先出）
    - 当插件被卸载、依赖失效、热更新重启：框架自动逆序全部执行清理函数
- Fiber & Effect 的关系
  - Fiber = 一次插件加载实例（拥有完整生命周期：PENDING → ACTIVE → DISPOSING → DISPOSED）
  - Effect = Fiber 管理的一条可撤销资源
  - 一个 Fiber 可以注册无数个 effect，形成一棵自动回收的资源树
  - 销毁顺序：后注册先清理（栈顺序），保证依赖关系安全释放
- 同步 / 异步两种形式
  - 同步 effect（普通清理函数）
    ```js
    ctx.effect(() => {
        const sub = onMessage(()=>{})
        return () => sub.off()
    })
    ```
  - 异步 effect（返回 Promise 的销毁函数）
    ```js
    ctx.effect(async () => {
        const proc = spawn('server')
        return async () => {
            proc.kill()
            await waitExit(proc)
        }
    })
    ```
# 三、可选依赖
inject 用于硬性依赖。如果某项功能缺失时插件仍可运行，请跳过 inject，并在使用处探测：

```ts
export function apply(ctx: Context) {
  // undefined when no provider is loaded; the plugin still runs.
  const greeter = ctx.get('greeter')
  console.log(greeter?.greet('maybe') ?? 'no greeter available')
}
```