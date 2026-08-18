# Agent Harness 完整技术详解：定义、架构、能力、代码示例、落地实践

当前行业构建生产级AI Agent已经形成共识公式：**Agent = LLM（模型大脑） \+ Harness（运行基础设施）**。
裸大模型只具备文本推理能力，无法独立完成长任务；**Harness 是包裹在大模型外部整套确定性工程运行框架**，也是Cursor、Claude Code、Trae等商用Agent底层核心设计思想。
本文全面讲解Harness概念、分层架构、核心能力、和Agent/框架的区别、简易实现示例、工程落地坑点。

## 一、核心定义与通俗理解

### 1\. 标准定义

**Agent Harness（智能体运行基座/智能体脚手架）**：围绕大语言模型构建的完整运行时控制系统，包含任务编排循环、状态管理、记忆体系、工具调度、上下文管控、安全护栏、异常容错、链路观测、结果校验等全部非模型能力。

行业经典论断：**只要不属于模型本身的代码与逻辑，全部属于Harness。**

### 2\. 形象类比（面试标准表述）

- 裸LLM = 一块没有外设、没有操作系统的CPU；

- 上下文窗口 = 内存（容量有限）；

- 向量库/持久存储 = 硬盘；

- 各类工具调用 = 外设驱动；

- **Harness = 操作系统**：统一调度资源、管控权限、管理生命周期、保障稳定运行；

- 最终对外表现出自主完成任务的实体 = Agent。

### 3\. 关键概念区分（极易混淆）

|名词|定位|核心职责|
|---|---|---|
|LLM 大模型|推理大脑|思考、规划、生成动作指令（概率性决策）|
|Agent（智能体）|对外表现出的智能行为|面向用户，目标驱动、自主调用工具完成任务|
|Agent框架（LangGraph/CrewAI）|开发组件库|提供状态图、循环、节点、检查点等基础组件|
|**Harness**|上层治理运行层|在框架之上增加确定性约束、管控、安全、校验、自愈体系|

简单一句话：LangGraph 提供画图的画布；Harness 定义画布上必须遵守的交通规则、红绿灯、护栏、故障应急方案。

## 二、Harness 七大核心能力模块（ETCLOVG标准体系）

工业界通用ETCLOVG分层模型，一套成熟Harness必须覆盖七层治理能力：

1. **E Environment 运行环境与沙箱边界**管控Agent可访问资源：文件读写权限、命令执行沙箱、网络访问白名单，隔离危险操作，防止越权破坏环境。

2. **T Tool 工具权限与风险闸门**工具注册、参数校验、危险操作人工审批（HITL）、黑白名单；高风险操作强制拦截或等待人类确认。

3. **C Context 上下文管理**上下文窗口监控、自动摘要压缩、历史裁剪、无用信息过滤，解决上下文溢出、Token持续膨胀问题。

4. **L Loop 循环控制与路由**最大迭代次数限制、死循环检测、重复动作熔断、条件分支路由、任务终止条件强制校验。

5. **O Observability 可观测与审计**全链路日志、每一步动作记录、Token消耗统计、耗时追踪、任务回放，出现问题可定位、可复盘。

6. **V Verification 结果校验与验证**工具返回结果校验、任务完成度判断、模型输出格式校验、识别虚假完成、幻觉结果拦截。

7. **G Governance 策略与人机治理**业务规则、合规策略、人工介入中断、子Agent权限隔离、成本限额熔断。

## 三、Harness 解决行业Agent普遍痛点

原生ReAct/LangGraph实现的简易Agent普遍存在大量工程缺陷，全部依靠Harness层兜底解决：

- ✅ 无限死循环 → Harness：循环次数上限、重复动作检测、熔断机制；
✅ 上下文持续膨胀、窗口溢出 → Harness：上下文自动压缩策略；
✅ 模型编造虚假工具参数 → Harness：工具入参强Schema校验；✅ Agent执行高危操作 → Harness：权限管控、人工审批闸门；
✅ 无法判断任务是否真正完成 → Harness：结果校验模块；
✅ 任务崩溃无法续跑 → Harness：状态持久化、断点恢复；
✅ 出问题无法定位原因 → Harness：全链路追踪审计日志；
✅ Token成本不可控 → Harness：用量监控、阈值熔断。
重要区分：**Harness通过确定性代码规则兜底风险；Prompt工程只能概率性引导模型。
Prompt解决“模型愿不愿意遵守规则”；Harness解决“系统强制只能做哪些操作”。二者互补，不可互相替代。**四、主流产品中的Harness实践案例五、极简Harness代码示例（基于LangGraph Python）下面实现一个轻量化最小Harness原型，包含：循环上限控制、上下文拦截、异常捕获、执行日志、简单结果校验。`
"""
极简 Agent Harness 演示
能力：循环管控、日志观测、异常兜底、最大步数限制、上下文拦截
"""
import logging
from typing import TypedDict, Annotated
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver
from langchain_openai import ChatOpenAI
from langchain_core.tools import tool

# ---------------------- 1. Harness基础配置（治理参数） ----------------------
MAX_LOOP_STEP = 5  # Harness强制限制最大迭代步数，防止死循环
logger = logging.getLogger("Agent-Harness")

# ---------------------- 2. 状态定义 ----------------------
class AgentState(TypedDict):
    messages: list
    step_count: int  # Harness用于记录执行步数

# ---------------------- 3. 业务工具 ----------------------
@tool
def query_database(keyword: str) -> str:
    """查询业务数据"""
    return f"{keyword} 的相关业务数据已查询完成"

tools = [query_database]
model = ChatOpenAI(model="gpt-4o-mini").bind_tools(tools)

# ---------------------- 4. Harness 拦截器/中间件能力 ----------------------
def harness_before_llm(state: AgentState):
    """Harness前置拦截：上下文裁剪、安全过滤、日志记录"""
    logger.info(f"【Harness】第{state['step_count']}轮开始调用模型")
    # 简易上下文控制：只保留最近6条消息（防止上下文爆炸）
    if len(state["messages"]) > 6:
        state["messages"] = state["messages"][-6:]
    return state

def harness_after_tool(state: AgentState):
    """Harness后置校验：工具执行结果校验、异常捕获"""
    logger.info(f"【Harness】工具执行完成，校验返回结果")
    return state

# ---------------------- 5. Graph节点 ----------------------
def agent_think(state: AgentState):
    state = harness_before_llm(state)
    resp = model.invoke(state["messages"])
    state["messages"].append(resp)
    state["step_count"] += 1
    return state

def tool_execute(state: AgentState):
    last_msg = state["messages"][-1]
    tool_calls = last_msg.tool_calls
    for call in tool_calls:
        tool_map = {t.name: t for t in tools}
        tool = tool_map[call["name"]]
        obs = tool.invoke(call["args"])
        state["messages"].append({"role":"tool", "tool_call_id":call["id"], "name":call["name"], "content":obs})
    state = harness_after_tool(state)
    return state

# ---------------------- 6. Harness路由规则（核心治理逻辑） ----------------------
def harness_router(state: AgentState):
    # Harness规则1：达到最大步数强制终止
    if state["step_count"] >= MAX_LOOP_STEP:
        logger.warning("【Harness警告】达到最大迭代步数，任务强制结束")
        return END
    last_msg = state["messages"][-1]
    # Harness规则2：判断是否继续调用工具
    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        return "tool_execute"
    return END

# ---------------------- 7. 组装图并运行 ----------------------
graph = StateGraph(AgentState)
graph.add_node("agent_think", agent_think)
graph.add_node("tool_execute", tool_execute)
graph.set_entry_point("agent_think")
graph.add_conditional_edges("agent_think", harness_router, {"tool_execute":"tool_execute", END:END})
graph.add_edge("tool_execute", "agent_think")

checkpointer = MemorySaver()
agent_app = graph.compile(checkpointer=checkpointer)

# 启动运行
res = agent_app.invoke({
    "messages": [{"role":"user","content":"查询AI Agent Harness相关资料"}],
    "step_count":0
}, config={"configurable":{"thread_id":"demo_001"}})

print(res["messages"][-1]["content"])
`代码说明：
示例中所有带harness\_前缀的函数、步数限制、路由熔断逻辑，都属于**Harness层代码**；模型推理、工具本身业务逻辑不属于Harness。
企业生产环境需要在此基础上扩展权限沙箱、结果校验、成本监控、人工中断、子Agent隔离等模块。六、Harness工程落地路线

    1. **Claude Code（Anthropic）**
    官方明确：Claude Code SDK本质就是一套成熟Agent Harness；提供文件沙箱、命令权限控制、步骤限制、人工审批、虚拟文件系统。
    

    2. **Cursor**
    自研ReAct循环内核，内置极简Harness层：文件操作权限控制、代码执行隔离、最大步骤限制、动作校验、上下文管理。
    

    3. **Trae（字节）**
    依托MCP协议构建标准化Harness，统一工具交互规范、执行沙箱、任务生命周期管理、操作审计。
    

    4. **LangChain DeepAgents**
    官方开源Harness实现，基于LangGraph封装多层中间件：任务规划中间件、子Agent隔离、上下文压缩、虚拟文件系统。
    

    1. 原型阶段：使用LangGraph搭建基础ReAct循环，先跑通基础任务；
    加固阶段：逐层叠加Harness能力：循环控制 → 上下文管控 → 日志观测 → 工具参数校验；
    生产阶段：增加沙箱隔离、权限治理、人工审批、任务结果验证、熔断限流；
    稳态阶段：统一抽象Harness基座，支持多Agent、多模型复用整套治理规则。
    

> (Note: May contain AI-generated content.)
