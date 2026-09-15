#!/usr/bin/env python3
"""
LangChain 文档加载器示例
展示了如何使用LangChain加载不同类型的文档
兼容 LangChain 旧版/新版包结构。
"""

try:
    # 旧版：加载器在 langchain.document_loaders 下
    from langchain.document_loaders import (
        TextLoader,
        CSVLoader,
        PyPDFLoader,
        WebBaseLoader,
        DirectoryLoader,
    )
except Exception:
    # 新版：加载器迁移到 langchain_community.document_loaders
    from langchain_community.document_loaders import (  # type: ignore
        TextLoader,
        CSVLoader,
        PyPDFLoader,
        WebBaseLoader,
        DirectoryLoader,
    )

try:
    # 旧版文本切分
    from langchain.text_splitter import RecursiveCharacterTextSplitter
except Exception:
    # 新版文本切分
    from langchain.text_splitters import RecursiveCharacterTextSplitter  # type: ignore

import os

print("===== 文本文件加载 =====")
# 创建示例文本文件
with open("sample.txt", "w", encoding="utf-8") as f:
    f.write(
        "LangChain是一个强大的LLM应用开发框架。\n它提供了丰富的工具和组件，帮助开发者快速构建LLM应用。\nLangChain的核心概念包括Chains、Agents、Tools等。")

# 加载文本文件
text_loader = TextLoader("sample.txt", encoding="utf-8")
text_documents = text_loader.load()
print(f"加载的文档数量: {len(text_documents)}")
print(f"文档内容: {text_documents[0].page_content}")
print(f"文档元数据: {text_documents[0].metadata}")
print("========================")

print("\n===== CSV文件加载 =====")
# 创建示例CSV文件
with open("sample.csv", "w", encoding="utf-8") as f:
    f.write("product,price,rating\n智能手机,5999,4.5\n笔记本电脑,8999,4.7\n平板电脑,3999,4.3")

# 加载CSV文件
csv_loader = CSVLoader("sample.csv", encoding="utf-8")
csv_documents = csv_loader.load()
print(f"加载的文档数量: {len(csv_documents)}")
print(f"文档内容: {csv_documents[0].page_content}")
print(f"文档元数据: {csv_documents[0].metadata}")
print("======================")

print("\n===== 网页加载 =====")
# 加载网页内容
web_loader = WebBaseLoader("https://python.langchain.com/docs/get_started/introduction")
web_documents = web_loader.load()
print(f"加载的文档数量: {len(web_documents)}")
print(f"文档内容长度: {len(web_documents[0].page_content)} 字符")
print(f"文档内容预览: {web_documents[0].page_content[:500]}...")
print(f"文档元数据: {web_documents[0].metadata}")
print("====================")

print("\n===== 目录加载 =====")
# 加载目录中的所有文本文件
dir_loader = DirectoryLoader(".", glob="*.txt", loader_cls=TextLoader, encoding="utf-8")
dir_documents = dir_loader.load()
print(f"加载的文档数量: {len(dir_documents)}")
for doc in dir_documents:
    print(f"- {doc.metadata['source']}: {len(doc.page_content)} 字符")
print("====================")

print("\n===== 文档分割 =====")
# 分割文档为小块
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=100,
    chunk_overlap=20
)

# 分割文本
chunks = text_splitter.split_documents(text_documents)
print(f"分割后的文档块数量: {len(chunks)}")
for i, chunk in enumerate(chunks):
    print(f"块 {i + 1}: {chunk.page_content}")
print("====================")

# 清理临时文件
if os.path.exists("sample.txt"):
    os.remove("sample.txt")
if os.path.exists("sample.csv"):
    os.remove("sample.csv")
