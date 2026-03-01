#!/usr/bin/env python3
"""
LangChain 基本 Chain 示例
展示了LangChain中最基本的Chain使用方法
"""

from langchain_core.prompts import PromptTemplate
from langchain_openai import ChatOpenAI
from llm_connection import get_openai_chat_llm

# 初始化LLM
llm = get_openai_chat_llm(
    temperature=0.7
)

# 创建提示模板
prompt = PromptTemplate(
    input_variables=["topic"],
    template="请简要介绍一下{topic}，限制在200字以内。"
)

# 格式化提示并运行
formatted_prompt = prompt.format(topic="人工智能")
result = llm.invoke(formatted_prompt)
print("===== 基本示例结果 =====")
print(result.content)
print("========================")

# 另一个示例：使用多个变量
prompt2 = PromptTemplate(
    input_variables=["topic", "length"],
    template="请介绍{topic}，限制在{length}字以内。"
)

formatted_prompt2 = prompt2.format(topic="机器学习", length="150")
result2 = llm.invoke(formatted_prompt2)
print("\n===== 多变量示例结果 =====")
print(result2.content)
print("==========================")
