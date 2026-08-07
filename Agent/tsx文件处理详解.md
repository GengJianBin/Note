# TSX 文件处理详解

TSX 文件本质是 **TypeScript + JSX**，在前端工程里主要解决两个问题：**语法解析** 和 **最终产物生成**。下面按"从源码到浏览器可运行代码"的链路来讲清楚它是怎么被处理的。

---

## 一、TSX 是什么

- `.tsx` = TypeScript + JSX
- JSX：类似 HTML 的语法，用于描述 UI（React 最典型）
- TypeScript：给 JS 加上静态类型系统

示例：

```tsx
interface Props {
  name: string;
}

const Hello: React.FC<Props> = ({ name }) => {
  return <h1>Hello {name}</h1>;
};
```

> 浏览器**无法直接运行 TSX**，必须经过编译处理。

---

## 二、整体处理流程（核心链路）

```
TSX 源码
  ↓
编译器（tsc / Babel / swc / esbuild）
  ↓
JS（React.createElement 或 JSX 运行时）
  ↓
打包工具（Webpack / Vite / Rspack 等）
  ↓
优化、压缩、Code Splitting
  ↓
浏览器可运行的 JS
```

---

## 三、关键处理环节拆解

### 1️⃣ 解析 & 转译（最重要的一步）

#### ✅ 方式一：`tsc`（TypeScript Compiler）

- 负责：
  - 类型检查
  - 把 TS/TSX → JS

- 配置示例（`tsconfig.json`）：

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "jsx": "react-jsx",
    "strict": true
  }
}
```

`jsx` 常见取值：

| 值 | 说明 |
|---|---|
| `react` | 转成 `React.createElement` |
| `react-jsx` | 转成新的 JSX runtime（`jsx()` / `jsxs()`） |
| `preserve` | 保留 JSX，交给 Babel 处理 |

> ⚠️ `tsc` 不做 polyfill、不打包，一般只做**类型检查 + 转译**。

---

#### ✅ 方式二：Babel（传统主流）

React 项目最常见。

- 插件：`@babel/preset-typescript`
- 预设：`@babel/preset-react`

```json
{
  "presets": [
    "@babel/preset-env",
    "@babel/preset-typescript",
    ["@babel/preset-react", { "runtime": "automatic" }]
  ]
}
```

作用：
- 删除 TS 类型
- 把 JSX 转成 JS 函数调用
- 支持浏览器兼容语法

---

#### ✅ 方式三：SWC / ESBuild（现代方案）

- 用 Rust / Go 写的，速度极快
- 常用于：
  - Next.js（SWC）
  - Vite（ESBuild 预构建）

```ts
// vite.config.ts
export default defineConfig({
  esbuild: {
    jsx: 'automatic',
  },
});
```

- ✅ 优点：快
- ❌ 缺点：类型检查不如 tsc 严谨（通常仍需 `tsc --noEmit`）

---

### 2️⃣ JSX 到底被转成了什么？

#### 旧版（runtime: classic）

```tsx
<div>hello</div>
```

↓ 转译为：

```js
React.createElement("div", null, "hello");
```

> 👉 必须 `import React from 'react'`

---

#### 新版（runtime: automatic，推荐 ✅）

```tsx
<div>hello</div>
```

↓ 转译为：

```js
import { jsx as _jsx } from "react/jsx-runtime";
_jsx("div", { children: "hello" });
```

> 👉 **不需要手动 import React**

---

### 3️⃣ 类型检查在哪一步？

> ⚠️ 很多人会误解：**JSX 转译 ≠ 类型检查**

| 工具 | 是否做类型检查 |
|---|---|
| tsc | ✅ 是 |
| Babel | ❌ 否 |
| SWC | ❌ 几乎不做 |
| ESBuild | ❌ 否 |

✅ **最佳实践：**

- 构建用 **Vite / Webpack + SWC / ESBuild**
- 类型检查单独跑：

```bash
tsc --noEmit
```

或在 IDE 中实时检查。

---

### 4️⃣ 打包阶段如何处理 `.tsx`

#### Vite

- 用 **ESBuild** 预编译 TSX
- 开发环境：
  - 原生 ESM
  - 按需编译，极快 HMR
- 生产环境：
  - Rollup 打包
  - Tree Shaking、压缩

#### Webpack

- `ts-loader`（慢，但类型检查强）
- `babel-loader + @babel/preset-typescript`（快，主流）

---

### 5️⃣ 为什么一定要 `.tsx` 而不是 `.ts`？

因为 JSX 语法在 `.ts` 文件中**不被允许**。

```ts
// ❌ .ts 文件
const el = <div />; // 语法错误
```

```tsx
// ✅ .tsx 文件
const el = <div />;
```

> TypeScript 编译器通过**文件扩展名**决定是否启用 JSX 解析。

---

## 四、完整的 tsconfig 示例（React）

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["DOM", "DOM.Iterable", "ESNext"],
    "module": "ESNext",
    "jsx": "react-jsx",
    "moduleResolution": "Node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

---

## 五、总结

> **TSX 文件的处理 = 用编译器把 TypeScript + JSX 转成浏览器能执行的 JavaScript，并由打包工具完成优化和分发；类型检查通常独立于构建流程存在。**
