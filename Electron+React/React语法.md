# React useState 及相关钩子函数详解

## 一、useState 是什么
`useState` 是 React 内置**状态钩子(Hook)**，仅能在函数组件 / 自定义 Hook 中使用。
作用：给函数组件**创建响应式状态数据**，状态变更会触发组件重新渲染。

### 语法
```tsx
const [state, setState] = useState(initialValue);
```

- `state`：当前状态值，**只读，不要直接修改**
- `setState`：状态更新函数，调用它才会更新状态并触发重渲染
- `initialValue`：初始值，组件首次渲染使用；后续渲染会忽略该参数

### 基础示例
```tsx
import { useState } from 'react';

function Counter() {
  // count：状态；setCount：更新函数；初始值 0
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>{count}</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
    </div>
  )
}
```

### TS 类型写法
1. 自动类型推断（简单类型）
```tsx
const [visible, setVisible] = useState(false); // 自动推断 boolean
```

2. 泛型指定类型（对象 / 可为 null）
```tsx
type User = { name: string } | null;
const [user, setUser] = useState<User>(null);
```

### setState 两种用法
1. 直接传新值
```tsx
setCount(10);
```

2. 函数式更新：接收上一次状态，返回新状态，适合依赖旧状态的场景
```tsx
setCount(prev => prev + 1);
```

> ⚠️ 注意：setState 是**异步批量更新**，调用后不能立刻拿到最新 state。

---

## 二、useState 周边 React 常用 Hook 分类

### 1. 状态类 Hook
#### useReducer
适合**复杂状态**，多个状态互相关联、大量状态修改逻辑。
替代 useState，类似 redux reducer 思想。
```tsx
const [state, dispatch] = useReducer(reducer, initialState);
```

#### useRef
1. 保存 DOM 元素引用
2. **保存可变变量，修改不会触发组件重渲染**
```tsx
const domRef = useRef<HTMLDivElement>(null);
const timerRef = useRef<number | null>(null);
```

### 2. 副作用 / 生命周期类 Hook
#### useEffect
处理副作用：请求接口、订阅事件、定时器、DOM操作。
模拟类组件 `componentDidMount / componentDidUpdate / componentWillUnmount`。
```tsx
useEffect(() => {
  // 执行逻辑
  return () => {
    // 清理函数：组件卸载 / effect重新执行前触发
  };
}, [deps]); // 依赖数组，控制何时执行
```
- `[]`：仅组件挂载执行一次
- `[a,b]`：a或b变化就执行
- 不传依赖数组：每次渲染都执行

#### useLayoutEffect
和 useEffect API 完全一致；
**执行时机更早：DOM 更新完成，但浏览器还没有绘制屏幕前执行**。
适合需要同步读取/修改DOM布局，会阻塞渲染；优先用 useEffect。

### 3. 缓存性能优化类 Hook
#### useMemo
缓存**计算结果**，避免每次渲染重复执行昂贵计算。
```tsx
const result = useMemo(() => heavyCompute(a,b), [a,b]);
```

#### useCallback
缓存**函数引用**，防止子组件接收回调 props 时频繁重渲染。
```tsx
const handleClick = useCallback(()=>{}, [deps]);
```

> useMemo / useCallback 不要滥用，本身有开销，只做性能优化。

### 4. 上下文 & 其他 Hook
#### useContext
读取 Context 上下文，跨组件传参。
```tsx
const value = useContext(MyContext);
```

#### useImperativeHandle
配合 forwardRef，暴露组件内部实例方法给父组件 ref。

---

## 三、关键对比总结
| Hook | 核心用途 | 是否触发重渲染 |
|---|---|---|
| useState | 创建响应式状态 | ✅ set更新触发重渲染 |
| useReducer | 复杂状态管理 | ✅ dispatch更新触发重渲染 |
| useRef | 存DOM / 可变变量 | ❌ 修改.current不会重渲染 |
| useEffect | 副作用、异步逻辑 | ❗不直接改状态就不触发渲染 |
| useMemo | 缓存计算值 | ❗缓存结果，不主动触发渲染 |
| useCallback | 缓存函数引用 | ❗缓存函数，不主动触发渲染 |

## 四、重要注意事项
1. Hook 调用规则：**只能在函数组件、自定义Hook顶层调用，不能放在if/for循环内部**
2. useState 更新是**替换**不是合并；对象状态更新需要完整传新对象
```tsx
// ❌错误，不会合并
setUser({name:'jack'})
// ✅正确展开旧状态
setUser(prev => ({...prev, name:'jack'}))
```
3. state 是渲染快照；effect、闭包内拿到的 state 是创建那一刻的值。


## 五、useState 状态存储与 DOM 更新逻辑解析
> 问题：
> 1.解答状态存React内部、DOM取值、是否每种类型只能存一份
> 2.useState把和UI相关的状态值存入React，当React更新DOM时，DOM会使用存储的值去更新DOM中的数据，对么？

你的理解前半部分：大体正确，但表述需要修正
✅ 核心思路正确，细节纠正：
1. useState **不会把变量存到你组件函数的局部变量里**，状态真正存储在 React 内部 Fiber 节点上（每个组件实例对应一个Fiber）。
2. `const [count, setCount] = useState(0)`，`count` 只是**本次渲染从Fiber里读取出来的快照副本**，不是数据源本身。
3. 当你调用 `setX()`，是修改 **Fiber内部存储的状态**，标记组件需要重渲染。
4. 组件重渲染时，重新执行组件函数，useState 从 Fiber 读取最新状态返回得到新快照；
5. JSX 中使用这个快照生成虚拟DOM；Reconciler对比虚拟DOM差异；最终Commit阶段用新数据更新真实DOM。

> 简单链路：
> setX → 更新Fiber内部状态 → 触发重渲染 → useState读取最新状态 → JSX生成VNode → Diff → 更新真实DOM

> 注意：**DOM本身不保存状态源**，DOM只是渲染结果；状态源保管在React Fiber。

---

## 六、第二个问题：那这样是不是每个类型的值只能存储一份呢？
❌ **不是按“数据类型”限制存储份数，是按 `useState` 的调用顺序来存储**

### 1. 存储的key：Hook调用顺序，不是类型
React 在组件实例 Fiber 上维护一条 **Hook链表**。
每调用一次 `useState`，就往链表追加一个Hook节点，保存这份状态。
**和值是 string / number / object 没有任何关系。**

示例：
```tsx
function Demo() {
  // Hook链表第0位：存数字
  const [count, setCount] = useState(0);
  // Hook链表第1位：同样存数字，完全独立，互不干扰
  const [total, setTotal] = useState(100);
  // Hook链表第2位：存字符串
  const [name, setName] = useState('');

  return <div>{count} {total} {name}</div>
}
```
- 两个number状态，分别放在链表0、1两个不同Hook节点，可以同时存在。
- 类型相同完全没问题；**区分靠调用顺序，不靠类型**。

> ⚠️ 这就是为什么Hook不能写在if、for里面：
> 如果条件分支导致 useState 调用顺序变化，链表索引错乱，状态就会读错。

### 2. 同一个对象类型，也可以多份独立存储
```tsx
type Item = {id:number}
const [a, setA] = useState<Item|null>(null);
const [b, setB] = useState<Item|null>(null);
```
两份完全独立对象状态，互不影响。

### 3. 容易混淆：什么时候是“一份”
**同一个 useState 调用，对应Fiber Hook链表中的一个存储槽位，只能存一份值。**
```tsx
// 这一个Hook槽位，同一时刻只能存一个value
const [value, setValue] = useState(initVal)
```
你可以修改它的值，但这一个槽位只能存一份；想要多份，就多调用几次 useState。

### 4. 想要存数组/列表多条数据怎么办？
不要循环写useState；把数组作为**单个状态值**放到一个useState槽位：
```tsx
// ✅一个Hook槽位，内部存数组，数组可以有N条数据
const [list, setList] = useState([{id:1},{id:2}])
```

## 七、关键总结表
| 问题 | 结论 |
|---|---|
| 状态存在哪里？ | 组件实例对应的Fiber上，Hook单向链表 |
| count变量是什么？ | 每次渲染读取出来的快照副本，不是源数据 |
| DOM直接读取Fiber状态吗？ | 不；先经过组件执行、JSX虚拟DOM，再更新DOM |
| 按类型限制份数？ | ❌不按类型；相同类型可以多份 |
| 如何区分多个状态？ | **useState调用顺序（Hook链表索引）** |
| 单个useState槽位 | 同一时刻只能保存一份值，可以更新覆盖 |

## 易错点
1. 不要理解成：React内部有个全局map，key是类型名。不是。
2. 多个组件实例：每个组件实例拥有自己独立的Hook链表。同样的组件渲染两次，状态完全隔离。

##  八、「组件」和「状态」是怎么对应上的，讲清楚。

### 8.1. 先给一句话结论

组件和状态不是“自动对应”的，而是通过「响应式系统」把「状态变化」映射成「组件重新渲染」。  

状态是数据，组件是函数，响应式系统负责“当状态变了，重新调用组件函数”。

### 8.2. 最底层：DOM 和数据的原始关系

没有框架时（原生 JS）
```js
let count = 0;

function render() {
  document.getElementById('app').innerHTML = `
    <button onclick="inc()">${count}</button>
  `;
}

function inc() {
  count++;
  render(); // 手动触发
}

render();
```
✅ 状态：count  
✅ 组件：render()  
❌ 问题：状态变了，必须手动调用 render

👉 这就是“组件和状态没自动对应上”的根源。

### 8.3. 现代框架的核心思想（React / Vue / Solid）

核心公式

状态 → 响应式系统 → 组件重新执行 → DOM 更新

### 8.4. 以 React 为例

1️⃣ 状态定义
``` js
const [count, setCount] = useState(0);


• count：当前状态

• setCount：唯一修改入口
```
2️⃣ 组件是“描述 UI 的函数”
```js
function App() {
  const [count, setCount] = useState(0);

  return (
    <button onClick={() => setCount(count + 1)}>
      {count}
    </button>
  );
}
```

✅ 组件返回的是 UI 描述（虚拟 DOM）  
✅ 不是真实 DOM

3️⃣ React 如何“对应”组件和状态？

当你调用：
``` js
setCount(count + 1);
```

React 内部做了 4 件事：

1. 更新状态值
2. 标记该组件为“需要重新渲染”
3. 重新执行 App() 函数
4. 对比新旧虚拟 DOM，只更新变化的部分

👉 状态 → 组件函数重新执行 → UI 更新

这就是“对应上”的本质。

### 8.5. Electron 里“组件和状态”的特殊点

Electron 有 两个世界

世界 技术

主进程 Node.js

渲染进程 React / Vue
状态分三类
状态类型 在哪里 示例

UI 状态 渲染进程 count, theme

应用状态 主进程 窗口列表、系统信息

共享状态 IPC 屏幕源、文件列表

### 8.6. 渲染进程：组件 ↔ 状态
```js
function ScreenShare() {
  const [sources, setSources] = useState([]);

  useEffect(() => {
    window.electron.getSources().then(setSources);
  }, []);

  return (
    <ul>
      {sources.map(s => <li key={s.id}>{s.name}</li>)}
    </ul>
  );
}
```

✅ sources 变了  
✅ 组件自动重新渲染  
✅ UI 自动更新

### 8.7. 主进程：状态在哪？

主进程 没有组件，只有：

• 窗口对象

• 系统资源

• IPC 状态
let mainWindow: BrowserWindow | null = null;


这是应用级状态，不是 UI 状态。

### 8.8. 组件和状态“对应”的关键机制总结

框架 对应机制

React useState → 重新执行组件

Vue ref/reactive → 依赖追踪

Solid 细粒度响应式

Svelte 编译期响应式

### 8.9. 你现在这个 Electron 项目里，完整链路是

```js
用户点击按钮
↓
setCount()
↓
React 重新执行 App()
↓
虚拟 DOM diff
↓
真实 DOM 更新
↓
（如果需要）通过 preload → 主进程
↓
desktopCapturer.getSources()
↓
IPC 返回数据
↓
setSources()
↓
组件再次更新
```