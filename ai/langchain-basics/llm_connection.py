#!/usr/bin/env python3
"""
大模型连接公共模块
用于处理大模型的连接配置和初始化
"""

from langchain_openai import ChatOpenAI, OpenAI
from langchain.llms import HuggingFaceHub
from dotenv import load_dotenv
import os

# 加载环境变量
load_dotenv()


def get_openai_chat_llm(model=None, temperature=0.7, **kwargs):
    """
    获取OpenAI Chat模型实例
    
    Args:
        model: 模型名称，默认为从.env中获取，若未设置则使用gpt-3.5-turbo
        temperature: 温度参数，默认为0.7
        **kwargs: 其他参数
    
    Returns:
        ChatOpenAI实例
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("未设置OPENAI_API_KEY环境变量")

    # 从.env中获取模型名称
    model_name = model or os.getenv("OPENAI_CHAT_MODEL", "gpt-3.5-turbo")

    # 从.env中获取API基础URL
    base_url = os.getenv("OPENAI_API_BASE")

    # 构建参数
    chat_kwargs = {
        "model": model_name,
        "temperature": temperature,
        "api_key": api_key,
        **kwargs
    }

    # 如果设置了base_url，则添加到参数中
    if base_url:
        chat_kwargs["base_url"] = base_url

    return ChatOpenAI(**chat_kwargs)


def get_openai_text_llm(model=None, temperature=0.7, **kwargs):
    """
    获取OpenAI文本模型实例
    
    Args:
        model: 模型名称，默认为从.env中获取，若未设置则使用gpt-3.5-turbo-instruct
        temperature: 温度参数，默认为0.7
        **kwargs: 其他参数
    
    Returns:
        OpenAI实例
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("未设置OPENAI_API_KEY环境变量")

    # 从.env中获取模型名称
    model_name = model or os.getenv("OPENAI_TEXT_MODEL", "gpt-3.5-turbo-instruct")

    # 从.env中获取API基础URL
    base_url = os.getenv("OPENAI_API_BASE")

    # 构建参数
    text_kwargs = {
        "model": model_name,
        "temperature": temperature,
        "api_key": api_key,
        **kwargs
    }

    # 如果设置了base_url，则添加到参数中
    if base_url:
        text_kwargs["base_url"] = base_url

    return OpenAI(**text_kwargs)


def get_huggingface_llm(repo_id=None, **model_kwargs):
    """
    获取HuggingFace模型实例
    
    Args:
        repo_id: 模型仓库ID，默认为从.env中获取，若未设置则使用google/flan-t5-large
        **model_kwargs: 模型参数
    
    Returns:
        HuggingFaceHub实例
    """
    api_token = os.getenv("HUGGINGFACEHUB_API_TOKEN")
    if not api_token:
        raise ValueError("未设置HUGGINGFACEHUB_API_TOKEN环境变量")

    # 从.env中获取模型仓库ID
    model_repo_id = repo_id or os.getenv("HUGGINGFACE_REPO_ID", "google/flan-t5-large")

    return HuggingFaceHub(
        repo_id=model_repo_id,
        model_kwargs=model_kwargs or {"temperature": 0.7, "max_length": 512}
    )


def get_embeddings():
    """
    获取嵌入模型实例
    
    Returns:
        OpenAIEmbeddings实例
    """
    from langchain.embeddings import OpenAIEmbeddings

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("未设置OPENAI_API_KEY环境变量")

    # 从.env中获取API基础URL
    base_url = os.getenv("OPENAI_API_BASE")

    # 构建参数
    embeddings_kwargs = {
        "api_key": api_key
    }

    # 如果设置了base_url，则添加到参数中
    if base_url:
        embeddings_kwargs["base_url"] = base_url

    return OpenAIEmbeddings(**embeddings_kwargs)
