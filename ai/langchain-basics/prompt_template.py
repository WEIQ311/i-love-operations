#!/usr/bin/env python3
"""
LangChain 提示模板示例
展示了如何使用LangChain的提示模板
"""

try:
    # 旧版：提示模板在 langchain.prompts 下
    from langchain.prompts import (  # type: ignore
        PromptTemplate,
        ChatPromptTemplate,
        HumanMessagePromptTemplate,
        SystemMessagePromptTemplate,
        AIMessagePromptTemplate,
    )
except Exception:
    # 新版：提示模板在 langchain_core.prompts 下
    from langchain_core.prompts import (  # type: ignore
        PromptTemplate,
        ChatPromptTemplate,
        HumanMessagePromptTemplate,
        SystemMessagePromptTemplate,
        AIMessagePromptTemplate,
    )

from llm_connection import get_openai_chat_llm

# 初始化LLM
llm = get_openai_chat_llm(
    temperature=0.7
)

print("===== 基本提示模板 =====")
# 基本提示模板
basic_template = PromptTemplate(
    input_variables=["product", "feature"],
    template="请描述{product}的{feature}功能，为什么它很重要？"
)

# 格式化提示
formatted_prompt = basic_template.format(product="智能手机", feature="摄像头")
print(formatted_prompt)

# 直接使用模板
result = llm.invoke(formatted_prompt)
print(result.content)
print("======================")

print("\n===== 聊天提示模板 =====")
# 聊天提示模板
chat_template = ChatPromptTemplate.from_messages([
    SystemMessagePromptTemplate.from_template("你是一个专业的产品顾问"),
    HumanMessagePromptTemplate.from_template("请介绍{product}的{feature}功能，为什么它很重要？")
])

# 格式化聊天提示
messages = chat_template.format_messages(product="笔记本电脑", feature="电池续航")
print(messages)

# 使用聊天提示
result2 = llm.invoke(messages)
print(result2.content)
print("========================")

print("\n===== 组合提示模板 =====")
# 组合提示模板
intro_template = "请介绍{topic}的基本概念"
task_template = "然后解释{topic}的应用场景"

# 组合两个模板
combined_template = intro_template + "。" + task_template
combined_prompt = PromptTemplate(
    input_variables=["topic"],
    template=combined_template
)

formatted_combined = combined_prompt.format(topic="区块链")
print(formatted_combined)

result3 = llm.invoke(formatted_combined)
print(result3.content)
print("========================")
