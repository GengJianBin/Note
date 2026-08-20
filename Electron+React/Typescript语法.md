# React.FC<> 与 import type 说明（前端工程师视角）

## React.FC<>
1. **全称**：`React.FunctionComponent`，React 内置泛型类型，用于定义**函数组件**的类型。
2. `<>` 内传入泛型参数：为组件的 `props` 类型。
3. 作用：TS 层面约束组件入参 props，自带默认 `children` 属性（旧版行为），返回值限定为 React 可渲染节点。
4. 示例：
```tsx
type Props = { name: string }
const Demo: React.FC<Props> = (props) => <div>{props.name}</div>
注意：现在官方更推荐直接手写函数签名，不完全依赖 React.FC，规避自带 children 的坑。
```
## import type
TS 专属导入语法，只导入类型，不导入运行时代码。
编译后会被完全擦除，不会产生 JS 打包产物，减小包体积。

区分：
```tsx
import xxx from './mod'：导入值（运行时有效），也可以附带类型；
import type { T } from './mod'：仅导入类型，仅 TS 编译阶段生效。
```
示例：
```tsx
import type { UserInfo } from './types'
const user: UserInfo = { id: 1 }
```
二者结合示例:
```tsx
import type { CardProps } from './card.type'
const Card: React.FC<CardProps> = (props) => <>{props.children}</>
```

## props 是什么
`props` 是父组件传给子组件的数据/回调函数，是函数组件的**入参对象**。
```tsx
// 父组件使用
<Hello name="张三" age={18} />

// 子组件接收
const Hello = (props) => {
  console.log(props.name, props.age)
  return <div></div>
}
```
## Record<K, T>
Record 源码解析

TS 内置源码：
```tsx
type Record<K extends keyof any, T> = { [P in K]: T; }
```

### 逐段拆解
**1. K extends keyof any**

keyof any 等价于 string | number | symbol，对象的合法键类型。

K extends keyof any：泛型约束，K 只能是可以作为对象 key 的类型。

所以 Record 的键只允许：字符串、数字、symbol。

**2. [P in K]**

in 是 TS 映射类型语法，遍历联合类型 K。

如果 K = 'screen' | 'window'

P in K 就依次取 'screen'、'window'，生成对象的属性名。

```tsx
type R = Record<'screen' | 'window', string>
// 等价展开：因为{ [P in K]: T; }中的: T表示的就是类型,见第2条
type R = {
  screen: string
  window: string
}
```
当你写 Record<string, string>：
K 是 string（不是字符串联合字面量），P in string 代表任意字符串，得到 { [P: string]: string }。

**3. : T**

遍历出来的每一个属性 P，它的值类型全部设置为 T。

## 为什么 map 里传 key，但 SourceItem props 接收不到 key
### 现象
```tsx
{sources.map((src) => (
  <SourceItem
    key={src.id}       // ✅这里写了 key
    source={src}
    isSelected={selectedId === src.id}
    onSelect={onSelect}
  />
))}

// SourceItem 组件解构，拿不到 key
const SourceItem: React.FC<ISourceItemProps> = ({
  source,
  isSelected,
  onSelect,
}) => {}
```

### key 是什么（React 特殊属性）
key 是 React 内部专用属性，不是普通 props。

1. 作用：map 渲染列表时，React Diff 算法用来识别每一个节点，判断哪些新增、删除、移动，优化 DOM 更新。
2. 传递规则：
- 写在 JSX 标签上：<SourceItem key={xxx} />
- React 把 key 拿走自己用，不会放进组件的 props 对象
- 组件内部 props.key 获取不到，TS 类型里也不会有 key。
  
`类似特殊属性还有 ref，也不会进到 props。`