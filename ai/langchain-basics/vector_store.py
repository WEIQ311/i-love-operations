#!/usr/bin/env python3
"""
LangChain 向量存储示例
展示了如何使用LangChain的向量存储进行相似性搜索
"""

try:
    # 旧版：向量存储在 langchain.vectorstores 下
    from langchain.vectorstores import FAISS  # type: ignore
except Exception:
    # 新版：向量存储迁移到 langchain_community.vectorstores
    from langchain_community.vectorstores import FAISS  # type: ignore

try:
    from langchain.document_loaders import TextLoader  # type: ignore
except Exception:
    from langchain_community.document_loaders import TextLoader  # type: ignore

try:
    from langchain.text_splitter import RecursiveCharacterTextSplitter
except Exception:
    from langchain.text_splitters import RecursiveCharacterTextSplitter  # type: ignore

from llm_connection import get_embeddings
import os

# 创建示例文档
with open("sample_docs.txt", "w", encoding="utf-8") as f:
    f.write("LangChain是一个强大的LLM应用开发框架。\n")
    f.write("它提供了丰富的工具和组件，帮助开发者快速构建LLM应用。\n")
    f.write("LangChain的核心概念包括Chains、Agents、Tools等。\n")
    f.write("Chains允许你将多个步骤组合成一个流水线。\n")
    f.write("Agents可以根据用户的指令自动决定执行哪些操作。\n")
    f.write("Tools是Agents可以使用的外部工具，如搜索引擎、计算器等。\n")
    f.write("Vector Stores用于存储和检索嵌入向量，支持相似性搜索。\n")
    f.write("Document Loaders用于从不同来源加载文档，如文本文件、网页等。\n")

print("===== 向量存储示例 =====")

# 1. 加载文档
loader = TextLoader("sample_docs.txt", encoding="utf-8")
documents = loader.load()
print(f"加载的文档数量: {len(documents)}")

# 2. 分割文档
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=200,
    chunk_overlap=50
)
chunks = text_splitter.split_documents(documents)
print(f"分割后的文档块数量: {len(chunks)}")

# 3. 初始化嵌入模型
embeddings = get_embeddings()

# 4. 创建向量存储
vector_store = FAISS.from_documents(chunks, embeddings)
print("向量存储创建成功")

# 5. 相似性搜索
query = "什么是Agents？"
print(f"\n搜索查询: {query}")
similar_docs = vector_store.similarity_search(query, k=2)
print(f"找到的相似文档数量: {len(similar_docs)}")

for i, doc in enumerate(similar_docs):
    print(f"\n相似文档 {i + 1}:")
    print(doc.page_content)

# 6. 带分数的相似性搜索
print("\n===== 带分数的相似性搜索 =====")
similar_docs_with_score = vector_store.similarity_search_with_score(query, k=2)

for doc, score in similar_docs_with_score:
    print(f"\n文档内容: {doc.page_content}")
    print(f"相似度分数: {score}")

# 7. 保存和加载向量存储
print("\n===== 保存和加载向量存储 =====")
vector_store.save_local("faiss_index")
print("向量存储保存成功")

# 加载向量存储
loaded_vector_store = FAISS.load_local("faiss_index", embeddings, allow_dangerous_deserialization=True)
print("向量存储加载成功")

# 验证加载后的向量存储
loaded_similar_docs = loaded_vector_store.similarity_search(query, k=2)
print(f"加载后搜索找到的相似文档数量: {len(loaded_similar_docs)}")

# 清理临时文件
if os.path.exists("sample_docs.txt"):
    os.remove("sample_docs.txt")

# 清理向量存储目录
import shutil

if os.path.exists("faiss_index"):
    shutil.rmtree("faiss_index")

print("\n向量存储示例完成")
