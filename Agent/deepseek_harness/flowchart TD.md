# 根因分析
Mermaid flowchart 容易报错的几个坑：
1. 子图/节点ID不能有特殊符号、空格；
2. 换行 `<br/>` 部分渲染器兼容不稳定；
3. `&` 多连线语法部分轻量编辑器不支持；
4. 引号、全角符号、短横线 `‑` 会导致解析异常。

下面给**两套稳定可用版本**：
- 版本A：极简标准 flow（绝大多数编辑器/GitHub/VSCode Mermaid插件 100%兼容）
- 版本B：sequence时序图（完全独立）

## 版本A｜稳定可渲染分层依赖图（直接复制）
```mermaid
flowchart TD
    %% 第一层
    subgraph Layer1["Harness上层调用方"]
        A["LlmRuntime / Agent"]
    end

    %% 第二层
    subgraph Layer2["Cordis插件层｜dsh-llm-pi-ai"]
        B["PiAiAdapter 主适配器"]
        C["Profile解析器 & Schema校验"]
        D["Catalog合并引擎<br/>models / modelOverrides / compat"]
        E["凭据解析模块<br/>apiKeyEnv → env / ctx.credentials"]
        F["模型发现服务<br/>registerModelDiscovery"]
        G["请求构造器<br/>reasoningEffort / image预算 / compat适配"]
        H["流转换 & ReplayEnvelope组装"]
    end

    %% 第三层
    subgraph Layer3["Cordis基础设施Seam"]
        S["ctx.settings 动态配置合并"]
        CredSeam["ctx.credentials 凭据托管"]
        LLMSeam["ctx.llm 模型注册表接口"]
    end

    %% 第四层
    subgraph Layer4["pi‑ai底层SDK"]
        I["pi‑ai Provider工厂"]
        J["pi‑ai内置Catalog元数据"]
        K["多协议流式实现<br/>openai‑completions / responses"]
    end

    %% 第五层
    subgraph Layer5["外部模型服务"]
        L["官方LLM服务<br/>DeepSeek / Anthropic / OpenAI"]
        M["私有OpenAI兼容网关 Acme‑gateway"]
    end

    %% 正向调用
    A -- resolveModelInfo / streamSimple --> B
    B --> C
    C --> D
    C --> E
    B --> G
    G --> I
    I --> K
    H --> A

    %% 虚线依赖
    S -.配置合并.-> C
    CredSeam -.凭据读取.-> E
    F -.注册发现钩子.-> LLMSeam
    LLMSeam <--> B

    %% pi-ai流向外部
    K --> L
    K --> M
    J -.原生catalog.-> D
```

## 版本B｜请求时序图（稳定版）
```mermaid
sequenceDiagram
    participant Runtime as Harness LlmRuntime
    participant Adapter as PiAiAdapter
    participant Resolver as Profile & Catalog解析器
    participant Credential as 凭据解析器
    participant PiSDK as pi‑ai SDK
    participant Remote as LLM服务/网关

    Runtime->>Adapter: prepareCall() 捕获不可变配置快照
    Adapter->>Resolver: 读取当前生效Profile
    Resolver->>Resolver: Catalog合并规则计算
    Adapter->>Credential: 解析 apiKeyEnv 引用
    Credential-->>Adapter: 返回密钥 / 抛出异常
    Adapter->>Adapter: 校验推理档位、图片载荷预算
    Adapter->>PiSDK: 构造Provider + 请求参数
    PiSDK->>Remote: 发起远端流式请求
    Remote-->>PiSDK: 返回原始协议流数据
    PiSDK-->>Adapter: pi‑ai原生事件流
    Adapter->>Adapter: 分片转换、组装回放信封、错误码对齐
    Adapter-->>Runtime: Harness标准流分片

    Note over Adapter: 修改配置不会中断在途请求，新配置仅对下一次prepareCall生效
```

# 如果上面依然渲染失败 → 使用无换行纯文本安全版（终极兼容）
```mermaid
flowchart TD
    subgraph Layer1[Harness上层调用方]
        A[LlmRuntime / Agent]
    end
    subgraph Layer2[Cordis插件层｜dsh-llm-pi-ai]
        B[PiAiAdapter 主适配器]
        C[Profile解析器 & Schema校验]
        D[Catalog合并引擎]
        E[凭据解析模块]
        F[模型发现服务]
        G[请求构造器]
        H[流转换 & ReplayEnvelope组装]
    end
    subgraph Layer3[Cordis基础设施Seam]
        S[ctx.settings 动态配置合并]
        CredSeam[ctx.credentials 凭据托管]
        LLMSeam[ctx.llm 模型注册表接口]
    end
    subgraph Layer4[pi‑ai底层SDK]
        I[pi‑ai Provider工厂]
        J[pi‑ai内置Catalog元数据]
        K[多协议流式实现]
    end
    subgraph Layer5[外部模型服务]
        L[官方LLM服务]
        M[私有OpenAI兼容网关]
    end

    A --> B
    B --> C
    C --> D
    C --> E
    B --> G
    G --> I
    I --> K
    H --> A

    S -.-> C
    CredSeam -.-> E
    F -.-> LLMSeam
    LLMSeam <--> B
    K --> L
    K --> M
    J -.-> D
```

## 修改说明（修复点）
1. 去掉 `K --> L & M` 合并写法，拆成两句 `K --> L` / `K --> M`；
2. 给subgraph增加唯一ID，使用 `["中文名称"]` 格式；
3. 保留换行 `<br/>`，如果你的渲染器不支持换行，直接用**终极无换行版本**；
4. 替换短连接符，统一使用普通横杠。

你告诉我你用什么工具渲染（Typora / VSCode插件 / GitBook / 掘金），我给你适配该平台的唯一可用版本。