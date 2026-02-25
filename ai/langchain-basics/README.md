# LangChain 基本代码示例

本目录包含了LangChain的基本代码示例，展示了LangChain的核心功能和使用方法。这些示例适用于使用conda环境中的algo-workspace，并支持从配置文件中灵活管理大模型连接。

## 学习资源

### LangChain学习指南

本项目提供了详细的LangChain学习指南：

- **LANGCHAIN_LEARNING_GUIDE.md** - 包含LangChain的核心概念、使用方法、最佳实践和常见问题解答，适合LangChain初学者

如果您对LangChain完全不了解，建议先阅读此学习指南，然后再运行示例代码。

## 目录结构

```
langchain-basics/
├── requirements.txt             # 依赖包配置
├── README.md                    # 本说明文档
├── LANGCHAIN_LEARNING_GUIDE.md  # LangChain学习指南
├── llm_connection.py            # 大模型连接公共模块
├── basic_chain.py               # 基本Chain示例
├── prompt_template.py           # 提示模板示例
├── llm_integration.py           # LLM集成示例
├── document_loaders.py          # 文档加载器示例
├── vector_store.py              # 向量存储示例
├── agent_example.py             # 智能体示例
└── .env_template                # 环境变量模板文件
```

## 安装依赖

使用conda环境中的algo-workspace：

```bash
# 激活conda环境
conda activate algo-workspace

# 安装依赖
pip install -r requirements.txt
```

## 配置环境变量

在运行示例前，需要配置环境变量。项目提供了 `.env_template` 文件作为模板：

1. **复制模板文件为 `.env`**：

```bash
cp .env_template .env
```

2. **编辑 `.env` 文件**，根据您的实际情况配置以下参数：

```bash
# OpenAI API密钥
OPENAI_API_KEY=your_openai_api_key

# OpenAI API基础URL (可选，支持非官方服务)
# OPENAI_API_BASE=https://api.openai.com/v1

# OpenAI Chat模型名称
# OPENAI_CHAT_MODEL=gpt-3.5-turbo

# OpenAI文本模型名称
# OPENAI_TEXT_MODEL=gpt-3.5-turbo-instruct

# HuggingFace Hub API令牌 (可选)
# HUGGINGFACEHUB_API_TOKEN=your_huggingface_api_token

# HuggingFace模型仓库ID
# HUGGINGFACE_REPO_ID=google/flan-t5-large

# SerpAPI API密钥 (可选，用于智能体示例)
# SERPAPI_API_KEY=your_serpapi_api_key
```

3. **替换相应的值**为您的实际API密钥和配置。

## 核心模块说明

### 1. 大模型连接公共模块 (`llm_connection.py`)
- **功能**：统一管理大模型的连接配置和初始化
- **特性**：
  - 从 `.env` 文件中读取所有配置参数
  - 支持自定义API基础URL（适用于非官方OpenAI兼容服务）
  - 提供统一的接口获取不同类型的模型实例
- **主要函数**：
  - `get_openai_chat_llm()` - 获取OpenAI Chat模型实例
  - `get_openai_text_llm()` - 获取OpenAI文本模型实例
  - `get_huggingface_llm()` - 获取HuggingFace模型实例
  - `get_embeddings()` - 获取嵌入模型实例

## 示例说明

### 1. 基本Chain示例 (`basic_chain.py`)
- **功能**：展示LangChain中最基本的Chain使用方法
- **内容**：
  - 简单的文本处理和模型调用
  - 多变量Chain示例
  - 使用公共连接模块从 `.env` 读取配置

### 2. 提示模板示例 (`prompt_template.py`)
- **功能**：展示如何使用LangChain的提示模板
- **内容**：
  - 基本提示模板
  - 聊天提示模板
  - 组合提示模板
  - 使用公共连接模块从 `.env` 读取配置

### 3. LLM集成示例 (`llm_integration.py`)
- **功能**：展示如何集成不同的LLM模型
- **内容**：
  - OpenAI Chat模型
  - OpenAI文本模型
  - HuggingFace模型（可选）
  - 模型参数调整
  - 所有模型配置从 `.env` 读取

### 4. 文档加载器示例 (`document_loaders.py`)
- **功能**：展示如何加载不同类型的文档
- **内容**：
  - 文本文件加载
  - CSV文件加载
  - 网页加载
  - 目录加载
  - 文档分割

### 5. 向量存储示例 (`vector_store.py`)
- **功能**：展示如何使用向量存储进行相似性搜索
- **内容**：
  - 文档分块和嵌入
  - 相似性搜索
  - 带分数的相似性搜索
  - 向量存储的保存和加载
  - 使用公共连接模块获取嵌入模型

### 6. 智能体示例 (`agent_example.py`)
- **功能**：展示如何创建和使用LangChain智能体
- **内容**：
  - 加载内置工具（数学工具、搜索工具）
  - 创建和使用自定义工具
  - 智能体初始化和测试
  - 使用公共连接模块从 `.env` 读取配置

## 运行示例

```bash
# 运行基本Chain示例
python basic_chain.py

# 运行提示模板示例
python prompt_template.py

# 运行LLM集成示例
python llm_integration.py

# 运行文档加载器示例
python document_loaders.py

# 运行向量存储示例
python vector_store.py

# 运行智能体示例
python agent_example.py
```

## 高级配置

### 使用非官方OpenAI兼容API服务

如果您想使用非官方的OpenAI兼容API服务，只需在 `.env` 文件中设置 `OPENAI_API_BASE`：

```bash
# 例如使用本地部署的API服务
OPENAI_API_BASE=http://localhost:8000/v1
```

### 切换不同的模型

您可以通过修改 `.env` 文件中的模型配置来切换不同的模型：

```bash
# 使用GPT-4模型
OPENAI_CHAT_MODEL=gpt-4

# 使用其他文本模型
OPENAI_TEXT_MODEL=gpt-3.5-turbo
```

## 注意事项

1. **API密钥**：确保配置了正确的API密钥
2. **环境**：使用conda环境中的algo-workspace
3. **网络连接**：确保网络连接正常，以便访问LLM API
4. **依赖版本**：确保安装了正确版本的依赖包
5. **配置文件**：所有配置都从 `.env` 文件读取，无需修改代码
6. **安全性**：不要将包含API密钥的 `.env` 文件提交到版本控制系统

## 故障排除

### 常见问题及解决方案

1. **API密钥错误**：
   - 症状：运行时出现API密钥相关错误
   - 解决：检查 `.env` 文件中的 `OPENAI_API_KEY` 是否正确设置

2. **模型不可用**：
   - 症状：运行时出现模型不存在或不可用的错误
   - 解决：检查 `.env` 文件中的模型名称是否正确，或尝试使用其他可用模型

3. **网络连接问题**：
   - 症状：运行时出现连接超时或网络错误
   - 解决：检查网络连接是否正常，或设置自定义的 `OPENAI_API_BASE`

4. **依赖缺失**：
   - 症状：运行时出现模块导入错误
   - 解决：确保已运行 `pip install -r requirements.txt` 安装所有依赖

## 参考资料

- [LangChain官方文档](https://python.langchain.com/docs/get_started/introduction)
- [LangChain GitHub仓库](https://github.com/langchain-ai/langchain)
- [OpenAI API文档](https://platform.openai.com/docs/introduction)
- [HuggingFace Hub文档](https://huggingface.co/docs/hub/index)
- [SerpAPI文档](https://serpapi.com/docs)
