#!/usr/bin/env python3
"""
LangChain 智能体示例
展示了如何使用LangChain的智能体
"""

from langchain.agents import AgentType, initialize_agent, load_tools
from langchain.tools import Tool
from langchain.utilities import SerpAPIWrapper
import os
from llm_connection import get_openai_chat_llm

print("===== 智能体示例 =====")

# 1. 初始化LLM
llm = get_openai_chat_llm(
    temperature=0.7
)

# 2. 加载工具
# 注意：使用SerpAPI需要设置SERPAPI_API_KEY环境变量
if os.getenv("SERPAPI_API_KEY"):
    tools = load_tools(["serpapi", "llm-math"], llm=llm)
    print("加载了SerpAPI和数学工具")
else:
    # 如果没有SERPAPI_API_KEY，只使用数学工具
    tools = load_tools(["llm-math"], llm=llm)
    print("只加载了数学工具（未设置SERPAPI_API_KEY）")


# 3. 添加自定义工具
def get_current_time(input_str):
    """获取当前时间"""
    from datetime import datetime
    return f"当前时间是: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"


# 创建自定义工具
custom_tool = Tool(
    name="GetCurrentTime",
    func=get_current_time,
    description="用于获取当前的日期和时间"
)

# 添加到工具列表
tools.append(custom_tool)
print("添加了自定义的获取时间工具")

# 4. 初始化智能体
agent = initialize_agent(
    tools=tools,
    llm=llm,
    agent=AgentType.CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)

print("智能体初始化成功")
print("====================")

# 5. 测试智能体
print("\n===== 测试智能体 =====")

# 测试数学工具
try:
    print("\n测试数学工具:")
    result1 = agent.invoke("3的平方加上4的平方等于多少？")
    print(f"结果: {result1['output']}")
except Exception as e:
    print(f"测试数学工具时出错: {e}")

# 测试自定义工具
try:
    print("\n测试自定义工具:")
    result2 = agent.invoke("现在几点了？")
    print(f"结果: {result2['output']}")
except Exception as e:
    print(f"测试自定义工具时出错: {e}")

# 测试搜索工具（如果有）
if os.getenv("SERPAPI_API_KEY"):
    try:
        print("\n测试搜索工具:")
        result3 = agent.invoke("2023年世界杯冠军是谁？")
        print(f"结果: {result3['output']}")
    except Exception as e:
        print(f"测试搜索工具时出错: {e}")
else:
    print("\n跳过搜索工具测试（未设置SERPAPI_API_KEY）")

print("\n智能体测试完成")
