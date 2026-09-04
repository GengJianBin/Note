# 一、Object.assign
## 1.作用
Object.assign(target, ...sources)  
把一个或多个源对象的可枚举属性，复制到目标对象，最后返回目标对  
- target：目标对象（会被直接修改） 
- sources：一个 / 多个源对象（不会改变）  
> 属于浅拷贝！
## 2.多个对象合并，后面的属性会覆盖前面的

## 3.重点：浅拷贝（只复制第一层）
如果属性值是对象 / 数组，复制的只是引用地址，修改嵌套对象两边都会变：
``` js
const obj = { info: { x: 1 } }
const copy = Object.assign({}, obj)

copy.info.x = 999
console.log(obj.info.x) // 999 原对象也变了！
```
## 4.对比 ES6 展开运算符（效果几乎一样）
```js
const merge = { ...o1, ...o2 }
// 等价于 Object.assign({}, o1, o2)
```
## 5.特殊规则
- 只复制可枚举属性，enumerable:false 的属性不会复制
- 不会复制原型链上的属性
- 如果 target 不是对象，会自动转成对象（基本类型会包装）
- null / undefined 作为源参数会直接忽略不报错

# 二、类型
## 1.JS的7大原始类型
- 原始类型(基本类型)： undefined / null / boolean / number / string / symbol / bigint → 原始值
- 引用类型（对象类型）：object → 引用类型（对象、数组、函数）
  - 只有一个根大类：object(也是typeof返回的字符串)，下面是它的各种子实例 
  - 内存中保存的是地址引用，存在堆内存；赋值是引用拷贝
- 7种原始类型是否区分大小写？
  - JS 内置原始类型对应的全局函数首字母全部大写（undefined和null除外，它们是特殊常量值）；其中 String/Number/Boolean/BigInt 既是普通转换函数，又是构造函数（支持 new）；Symbol 只是转换 / 创建函数，不是构造函数（不支持 new）
    - Symbol 是一个函数，但它「不能当作构造函数使用」（禁止 new）；其它几个 String/Number/Boolean/BigInt 既可以当普通函数，也可以 new 当构造函数。
  - 原始值的数据本身是否区分大小写，要看类型,比如:String类型的值区分大小写,Number和Bigint的值没有大小写的概念
  - 小写 string / number / boolean / symbol / bigint 不是函数！只是 typeof 返回的字符串标识
```plaintext
JS数据类型
├─ 原始类型（7个）
│   ├─ undefined
│   ├─ null
│   ├─ boolean
│   ├─ number
│   ├─ string
│   ├─ symbol
│   └─ bigint
│
└─ 引用类型（Object家族）
    ├─ Object 普通对象
    ├─ Array 数组
    ├─ Function 函数
    ├─ Date 日期
    ├─ RegExp 正则
    ├─ Map / Set
    └─ 包装对象 new String / Number / Boolean / BigInt //直接调用 String() / Number() / Boolean() / BigInt()（不加 new）得到的才是原始值。
```
  - 相等判断巨大区别
  ```js
  //原始值对比：按值比较
  '123' === '123' // true
  //包装对象对比：对比内存地址
  new String('123') === new String('123') // false！两个不同对象
  ``` 
## 2.undefined和null的区别
- undefined：声明了变量，但没有赋值，代表「缺值、未定义」
- null：人为手动赋值为空，代表「主动置空、空对象」
- typeof 结果
```js
typeof undefined // "undefined" ✅  
typeof null      // "object"  ❌ JS历史bug！null本身不是对象
```
- 值相等判断
```js
null == undefined  // true  宽松相等，两者都代表空
null === undefined // false 严格相等，类型不一样
```
- undefine使用场景
```js
//变量声明但没赋值
let x; // undefined

//函数没有 return 返回值
function fn(){}
fn() // undefined

//对象不存在的属性
const obj = {}
obj.name // undefined

//函数少传参数
function say(name){ console.log(name) }
say() // undefined
```

- null使用场景
```js
//手动清空一个引用对象
let user = {name:'小明'}
user = null; // 断开引用，交给垃圾回收

//接口返回空数据（后端查不到数据一般返回 null）
//作为参数，表示 “不传入对象”
```
- 开发规范小建议  
不要手动给变量赋值 undefined，交给 JS 自己管理  
如果要表示 “空对象 / 空数据”，用 null
## 3. symbol 和 bigint
- Symbol
  - 作用:生成一个独一无二的值，用来做对象的私有 / 唯一属性名，防止属性名冲突。
  - 创建方式
    ```js
    const s1 = Symbol()
    const s2 = Symbol()

    console.log(s1 === s2) // false！每次都是全新唯一值

    //括号里只是描述文本（备注），不影响唯一性：
    const s1 = Symbol('id')
    const s2 = Symbol('id')
    console.log(s1 === s2) // false
    ```
  - 作为对象属性名,普通字符串属性容易重名覆盖，Symbol 不会冲突：
    ```js
    const key = Symbol('id')
    const obj = {
        [key]: 100
    }
    ```
     > 注意：不能用 . 访问，必须用 []
  - 特性
    - 不能 new Symbol ()，不是构造函数
      - 不是构造函数为什么能够以函数调用的形式创建 ？
        - Symbol 本身是一个函数（内置函数对象），但不能用 new Symbol() 当作构造函数使用 **；
        - 直接写 Symbol(desc) 就是普通函数调用，不是实例化；
        - JS 语言给这个函数做了特殊设计：执行时返回一个唯一的 Symbol 原始值，而不是普通函数的返回逻辑。
    - typeof Symbol() === "symbol" ✔
    - for...in、Object.keys() 遍历不到 Symbol 属性
    - 如果要获取对象里所有 symbol 键：Object.getOwnPropertySymbols(obj)
  - Symbol.for () 全局共享 symbol
  ```js
    const s1 = Symbol.for('token')
    const s2 = Symbol.for('token')
    console.log(s1 === s2) // true，全局注册表复用
    ```
- Bigint
  - 解决什么问题：JS 的 Number 安全整数范围有限：
    > 安全最大值：2⁵³ − 1 → 9007199254740991  
    > 超过这个数字，Number 计算会丢失精度，数值不准！  
    > BigInt 用来表示超大整数，任意长度。
  - 两种创建写法
  ```js
  //数字末尾加 n
  const num = 9007199254740999n
  // BigInt() 函数
  const num2 = BigInt("9007199254740999")
  ```
## 4. Object和object
- object 
  - 小写 object（数据类型）
- Object本身是一个函数（构造函数）
    - Object()：构造函数，可以生成普通对象
    - Object.assign / Object.keys 都是它身上的静态方法（直接 Object.xxx() 调用）
    - Object.prototype 是它的原型对象
## 5.函数、对象和数组有什么区别？
### 5.1
- 对象是基础容器：键值对集合（key: value）
- 数组是特殊对象：数字下标 + length 属性的有序集合
- 函数也是特殊对象：可被调用，拥有执行代码的能力
> 三者都属于引用类型，存的是内存地址，赋值是引用拷贝。

### 5.2
  - 对象 Object
   > 本质：无序的键值对集合，key 是字符串 / Symbol
  - 对象 Array
   > 本质：继承自 Object 的特殊对象，key 是 0,1,2… 数字索引，自带 length
  - 函数 Function
   > 本质：可执行的特殊对象，除了属性，还拥有 [[Call]] / [[Construct]] 内部方法
## 6.const let和var区别
- 作用域区别
  - var：只认 function()，if/for/while 的 {} 对它无效
  - let / const：块级作用域，只要是 {} 就是独立作用域
- 变量提升 & 暂时性死区 TDZ
**var**
```js
console.log(x) // undefined（提升了，默认值undefined）
var x = 100
```

**let/const**
```js
console.log(y) // ReferenceError：暂时性死区
let y = 200
```
> 本质：let/const 也会提升，但是在代码执行到声明语句之前，禁止访问这个变量，这个区间叫暂时性死区
- 重复声明
```js
var num = 1
var num = 2 // 合法，覆盖

let n1 = 1
let n1 = 2 // Uncaught SyntaxError 不能重复声明
```
- const 的特殊点:**不能重新赋值，不是不能修改对象内部属性**
```js
const obj = {name:'张三'}
obj.name = '李四' // ✅ 可行，修改堆里面的数据
obj = {} // ❌ 报错，不能改变obj的内存地址
```
> const 保护的是栈里保存的引用地址不变，不是保护堆里面的数据不可变
- 最佳实践（开发规范）
优先使用 const，值不会被修改的变量一律用 const  
后续需要改变值的时候，使用 let  
尽量不要使用 var，避免作用域污染带来诡异 bug  
## 7.

## 10.== 和===的区别
- === 严格相等：先比较类型，再比较值，类型不同直接 false，不做隐式转换
- == 宽松相等：如果两边类型不一样，JS 会自动做隐式类型转换，再比较值
## 11.ES6 和 CommonJS

# 三、原型链
## 1. prototype & \__proto\__
- prototype（显式原型）：函数所有，可以看做一个容器对象，其中包含一些公共方法和\__proto\__,该对象的\__proto\__指向父类的构造的prototype。原型链的查找规则为：现在当前对象中的属性中查找，找不到则通过当前对象的\__proto\__属性（**指向该对象类型的构造函数的 prototype**）查找当前类型构造中的prototype对象中的方法，找不到，则通过prototype对象中的\__proto\__去寻找父类中的protptype中的方法，直至Object.protoType.__proto__（null）
- \__proto\__（隐式原型）：本质是原型链中的查找指针，对象所有，最底层的派生类对象中的\__proto\__**指向该对象类型的构造函数的 prototype**,构造函数的 prototype对象中的\__proto\__，指向父类的构造中的prototype，以此类推最终到Object.prototype.__proto__（null）。


## 2.原型链示例
继承关系
```js
class Animal {
  eat() {}
}
class Dog extends Animal {
  bark() {}
}
const dog = new Dog()
```

```plaintext
dog（实例对象）
└── __proto__ → Dog.prototype
    └── __proto__ → Animal.prototype
        └── __proto__ → Object.prototype
            └── __proto__ → null  // 链条终点
```

## 3.js中的Object类
> JS 大部分对象最终继承 Object.prototype，但使用 Object.create(null) 生成的对象原型直接为 null，不继承 Object，属于例外情况。
>

## 4. extends做了两件事：
extends 帮我们自动维护了两条原型链：
- 实例原型链：Child.prototype.\__proto\__ === Parent.prototype
- 构造函数原型链：Child.\__proto\__ === Parent
> 构造函数是函数，函数也是对象，有\__proto\__属性
> 实例原型链是通过\__proto\__来逐级指向父类中的prototype对象
> 构造函数原型链是通过\__proto\__来逐级指向父类的构造函数
>
# 四、async 和 await
async 用来标记异步函数；await 只能写在 async 函数内部，用来等待 Promise 完成。
## 4.1 async 关键字
任何函数前面加上 async，返回值永远自动包装成 Promise
```js
// 普通函数
function foo() { return 1 }

// async 函数
async function bar() { return 1 }
// 等价于 function bar() { return Promise.resolve(1) }
```
## 4.2 await
- 后面必须跟一个 Promise
- 暂停当前函数执行，等待 Promise resolve，拿到最终结果再往下走
- 如果 Promise reject，会抛出异常，可以用 try/catch 捕获
```js
async function demo() {
  const res = await fetch("xxx")
  const data = await res.json()
  console.log(data)
}
```

# 五、模块扩充
```ts
declare module '@deepseek-ai/cordis' {
  interface Events {
    'llm/adapters-updated'(): void
  }
}
```
## 5.1 解释
- declare module '包名' { ... }  
这是 TypeScript 的模块声明扩充语法
  - 不是新建一个模块；而是往已存在的第三方模块 @deepseek-ai/cordis 里追加类型定义
  - Cordis 内部已经定义过 interface Events；这段代码是给 Events 接口新增一条事件类型
> TS 特性：同一个模块、同一个 interface 会自动合并（Declaration Merging / 声明合并）

- interface Events
Cordis 框架约定：
Events 这个接口用来集中定义全部合法事件名 + 事件参数类型
```ts
// 框架原生代码大概长这样
interface Events {
  'start'(): void
  'exit'(): void
}
```
- 'llm/adapters-updated'(): void  
  这是 TypeScript 的调用签名（Call Signature），不是函数执行
  这是字符串字面量作为接口属性名，用来描述事件签名：
  - 事件名称：llm/adapters-updated
  - 触发时不带任何参数
  - 返回值无意义 void
  写完之后，当你写业务代码：
  ```ts
  // 类型校验生效
  ctx.emit('llm/adapters-updated')
  ctx.on('llm/adapters-updated', () => {})
  ```
  常见写法：
```ts
interface Events {
  // 无参数事件
  'a'(): void
  // 单个参数
  'b'(msg: string): void
  // 多个参数
  'c'(x: number, y: boolean): void
  // 可选参数
  'd'(v?: string): void
}
```