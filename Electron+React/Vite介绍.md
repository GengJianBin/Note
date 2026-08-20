# Vite 介绍

## 一、什么是 Vite

Vite（法语意为"快速"，发音 `/vit/`）是由 Vue.js 作者尤雨溪开发的新一代前端构建工具。它利用浏览器原生 ES 模块（ESM）和基于 esbuild 的预构建，提供了极快的冷启动速度和即时的热模块替换（HMR）。

## 二、Vite 的核心功能

### 1. 极速的开发服务器启动

- 基于原生 ESM，无需打包即可启动开发服务器
- 冷启动时间通常在毫秒级，不随项目规模增长而显著变慢
- 按需编译，只在浏览器请求时才转换对应模块

### 2. 即时热模块替换（HMR）

- 修改代码后浏览器即时更新，无需整页刷新
- HMR 速度与项目模块总数解耦，始终保持快速
- 支持 Vue、React、Svelte 等框架的组件级热更新

### 3. 高效的依赖预构建

- 使用 esbuild（Go 语言编写）进行依赖预构建
- 将 CommonJS / UMD 模块转换为 ESM 格式
- 预构建结果缓存，二次启动几乎瞬时

### 4. 丰富的插件生态

- 兼容 Rollup 插件接口，可复用大量现有插件
- 提供官方插件支持 Vue、React、TypeScript、CSS 预处理器等
- 支持自定义插件开发，扩展构建流程

### 5. 开箱即用的特性

- TypeScript 原生支持（仅转译，不做类型检查）
- JSX / TSX 支持
- CSS / Less / Sass / Stylus 支持
- 静态资源处理（图片、字体等）
- 环境变量与模式支持
- 多页面应用支持

### 6. 生产环境优化构建

- 基于 Rollup 进行生产打包，输出高度优化的静态资源
- 自动代码分割、Tree Shaking、资源压缩
- 支持构建为库（Library）模式
- 支持 SSR（服务端渲染）

## 三、Vite 的作用与优势

### 解决的痛点

| 传统构建工具问题 | Vite 的解决方案 |
|---|---|
| 冷启动慢，需先打包整个应用 | 基于 ESM 按需加载，启动无需打包 |
| HMR 随项目变大而变慢 | HMR 与模块数量解耦，始终快速 |
| 依赖构建耗时 | esbuild 预构建，速度提升 10-100 倍 |
| 配置复杂 | 零配置开箱即用，约定优于配置 |

### 适用场景

- 中小型到大型前端项目开发
- Vue / React / Svelte / Preact 等框架项目
- 需要快速原型开发的场景
- 库（Library）打包发布
- 多页面应用（MPA）
- SSR 项目

## 四、Vite 的使用方法

### 1. 环境要求

- Node.js 版本 >= 18.0.0（推荐 LTS 版本）
- 包管理器：npm / yarn / pnpm / bun

### 2. 创建项目

使用官方脚手架创建项目：

```bash
# npm
npm create vite@latest

# yarn
yarn create vite

# pnpm
pnpm create vite

# bun
bun create vite
```

按提示选择项目名称、框架模板（Vue / React / Vanilla 等）和语言（JavaScript / TypeScript）。

也可以一行命令直接指定：

```bash
# npm 6.x
npm create vite@latest my-vue-app --template vue

# npm 7+，需要额外的双横线
npm create vite@latest my-vue-app -- --template vue

# React + TypeScript
npm create vite@latest my-react-app -- --template react-ts
```

可用模板包括：`vanilla`、`vanilla-ts`、`vue`、`vue-ts`、`react`、`react-ts`、`react-swc`、`react-swc-ts`、`preact`、`preact-ts`、`lit`、`lit-ts`、`svelte`、`svelte-ts`、`solid`、`solid-ts`、`qwik`、`qwik-ts` 等。

### 3. 安装依赖并启动

```bash
cd my-vue-app

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

启动后终端会显示本地访问地址（默认 `http://localhost:5173/`），在浏览器打开即可。

### 4. 常用脚本命令

在 `package.json` 中通常包含以下脚本：

```json
{
  "scripts": {
    "dev": "vite",              // 启动开发服务器
    "build": "vite build",      // 构建生产版本
    "preview": "vite preview"   // 本地预览生产构建结果
  }
}
```

```bash
# 构建生产版本（输出到 dist 目录）
npm run build

# 预览构建结果
npm run preview
```

### 5. 项目结构

以 Vue + TypeScript 模板为例：

```
my-vue-app/
├── node_modules/       # 依赖包
├── public/             # 静态资源（不经过构建处理，直接复制）
│   └── vite.svg
├── src/                # 源代码目录
│   ├── assets/         # 资源文件（图片、样式等）
│   ├── components/     # 组件
│   ├── App.vue         # 根组件
│   ├── main.ts         # 入口文件
│   └── style.css       # 全局样式
├── index.html          # HTML 入口文件
├── package.json        # 项目配置
├── tsconfig.json       # TypeScript 配置
├── vite.config.ts      # Vite 配置文件
└── README.md
```

### 6. 配置文件 `vite.config.ts`

Vite 使用 `vite.config.js` 或 `vite.config.ts` 作为配置文件，位于项目根目录。

基础配置示例：

```ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  // 插件配置
  plugins: [vue()],

  // 路径别名
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },

  // 开发服务器配置
  server: {
    port: 3000,           // 端口号
    open: true,            // 自动打开浏览器
    host: '0.0.0.0',      // 允许外部访问
    proxy: {               // 代理配置
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  },

  // 构建配置
  build: {
    outDir: 'dist',        // 输出目录
    sourcemap: false,      // 是否生成 sourcemap
    minify: 'esbuild',     // 压缩方式
    rollupOptions: {       // Rollup 配置
      output: {
        chunkFileNames: 'js/[name]-[hash].js',
        entryFileNames: 'js/[name]-[hash].js',
        assetFileNames: '[ext]/[name]-[hash].[ext]'
      }
    }
  },

  // 环境变量前缀（默认 VITE_）
  envPrefix: 'VITE_'
})
```

### 7. 环境变量与模式

Vite 使用 dotenv 加载环境变量，文件命名规则：

```
.env                # 所有情况下都会加载
.env.local          # 所有情况下都会加载，会被 git 忽略
.env.[mode]         # 只在指定模式下加载
.env.[mode].local   # 只在指定模式下加载，会被 git 忽略
```

只有以 `VITE_` 开头的变量才会暴露到客户端代码中：

```bash
# .env.development
VITE_API_URL=http://localhost:3000/api
VITE_APP_TITLE=我的应用
```

在代码中使用：

```ts
console.log(import.meta.env.VITE_API_URL)
console.log(import.meta.env.VITE_APP_TITLE)

// 内置变量
import.meta.env.MODE        // 当前模式（development / production）
import.meta.env.DEV         // 是否开发环境
import.meta.env.PROD        // 是否生产环境
import.meta.env.SSR         // 是否服务端渲染
```

TypeScript 类型声明（`src/vite-env.d.ts`）：

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_APP_TITLE: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
```

### 8. 静态资源处理

#### 引入资源

```ts
// 引入图片，返回解析后的 URL
import logo from './assets/logo.png'

// CSS 中引用
.background {
  background-image: url('./assets/bg.jpg');
}
```

#### public 目录

放在 `public` 目录下的文件会被原样复制到构建输出根目录，引用时使用根路径：

```html
<img src="/vite.svg" alt="logo" />
```

### 9. CSS 处理

#### CSS Modules

命名为 `*.module.css` 的文件会被视为 CSS Modules：

```css
/* Button.module.css */
.btn {
  color: red;
}
```

```ts
import styles from './Button.module.css'

<button className={styles.btn}>按钮</button>
```

#### CSS 预处理器

安装对应预处理器即可使用，无需额外配置：

```bash
npm install -D less
# 或
npm install -D sass
# 或
npm install -D stylus
```

```vue
<style lang="less" scoped>
.container {
  .title {
    color: @primary-color;
  }
}
</style>
```

### 10. 常用插件

```bash
# Vue 官方插件
npm install -D @vitejs/plugin-vue

# React 官方插件
npm install -D @vitejs/plugin-react

# 自动导入 API
npm install -D unplugin-auto-import

# 自动导入组件
npm install -D unplugin-vue-components

# 打包分析
npm install -D rollup-plugin-visualizer

# 兼容旧浏览器
npm install -D @vitejs/plugin-legacy
```

## 五、Vite 与其他构建工具对比

| 特性 | Vite | Webpack | Vue CLI | Create React App |
|---|---|---|---|---|
| 开发服务器启动 | 极快（毫秒级） | 较慢 | 较慢 | 较慢 |
| HMR 速度 | 快，与规模无关 | 随规模变慢 | 随规模变慢 | 随规模变慢 |
| 生产构建 | Rollup | Webpack | Webpack | Webpack |
| 配置复杂度 | 低（零配置） | 高 | 中 | 低（但 eject 后高） |
| ESM 原生支持 | ✅ 核心特性 | ❌ 需配置 | ❌ | ❌ |
| 依赖预构建 | esbuild | - | - | - |

## 六、常见问题

### 1. 依赖预构建报错

删除缓存重新启动：

```bash
rm -rf node_modules/.vite
npm run dev
```

### 2. 路径别名不生效

确保 `vite.config.ts` 和 `tsconfig.json` 中都配置了别名：

```json
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

### 3. 生产构建后白屏

检查 `vite.config.ts` 中的 `base` 配置，部署到子路径时需要设置：

```ts
export default defineConfig({
  base: '/my-app/'  // 部署在子路径下
})
```

## 七、参考资源

- Vite 官方文档：https://vitejs.dev/
- Vite GitHub：https://github.com/vitejs/vite
-  awesome-vite：https://github.com/vitejs/awesome-vite
