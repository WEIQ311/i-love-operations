#!/usr/bin/env python3
"""
LangChain 基本 Chain 示例
展示了LangChain中最基本的Chain使用方法
"""

from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
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

# 创建Chain
chain = LLMChain(llm=llm, prompt=prompt)

# 运行Chain
result = chain.run("人工智能")
print("===== 基本Chain示例结果 =====")
print(result)
print("============================")

# 另一个示例：使用多个变量
prompt2 = PromptTemplate(
    input_variables=["topic", "length"],
    template="请介绍{topic}，限制在{length}字以内。"
)

chain2 = LLMChain(llm=llm, prompt=prompt2)
result2 = chain2.run(topic="机器学习", length="150")
print("\n===== 多变量Chain示例结果 =====")
print(result2)
print("==============================")
