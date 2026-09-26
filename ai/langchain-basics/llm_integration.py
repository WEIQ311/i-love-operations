#!/usr/bin/env python3
"""
LangChain LLM集成示例
展示了如何集成不同的LLM模型
"""

from llm_connection import get_openai_chat_llm, get_openai_text_llm, get_huggingface_llm
import os

print("===== OpenAI Chat模型 =====")
# OpenAI Chat模型
chat_openai = get_openai_chat_llm(
    temperature=0.7
)

result1 = chat_openai.invoke("请简要介绍LangChain")
print(result1.content)
print("========================")

print("\n===== OpenAI 文本模型 =====")
# OpenAI 文本模型
text_openai = get_openai_text_llm(
    temperature=0.7
)

result2 = text_openai.invoke("请简要介绍LangChain")
print(result2)
print("========================")

print("\n===== HuggingFace模型 (可选) =====")
# HuggingFace模型 (需要设置HUGGINGFACEHUB_API_TOKEN)
if os.getenv("HUGGINGFACEHUB_API_TOKEN"):
    hf_llm = get_huggingface_llm(
        temperature=0.7,
        max_length=512
    )

    result3 = hf_llm.invoke("请简要介绍LangChain")
    print(result3)
else:
    print("提示：未设置HUGGINGFACEHUB_API_TOKEN环境变量，跳过HuggingFace模型示例")
print("================================")

print("\n===== 模型参数调整 =====")
# 调整模型参数
custom_llm = get_openai_chat_llm(
    temperature=0.1,  # 降低温度，使输出更确定性
    max_tokens=200,  # 限制输出长度
    top_p=0.9,  # 调整top_p参数
)

result4 = custom_llm.invoke("请详细介绍LangChain的核心组件")
print(result4.content)
print("========================")
