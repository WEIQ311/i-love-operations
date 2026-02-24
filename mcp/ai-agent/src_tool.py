from __future__ import annotations

"""
对外暴露给大模型（function calling / tools）的统一入口。

约定的工具名称：query_database
"""

from typing import Any, Dict, Optional

from src_agent import build_default_agent


def query_database(
    natural_language_query: str,
    page: Optional[int] = None,
    page_size: Optional[int] = None,
) -> Dict[str, Any]:
    """
    统一查询入口：给大模型注册的 tool 函数。

    参数：
    - natural_language_query: 自然语言问题
    - page: 页码（从 1 开始，可选）
    - page_size: 每页大小（可选）

    返回：
    {
        "question": ...,
        "sql": ...,
        "columns": [...],
        "rows": [ {...}, ... ],
        "page": 1,
        "page_size": 50,
        "has_more": true/false,
    }
    """
    agent = build_default_agent()
    result = agent.ask(
        question=natural_language_query,
        page=page,
        page_size=page_size,
    )

    data = result.data
    return {
        "question": result.question,
        "sql": result.sql,
        "columns": data.get("columns", []),
        "rows": data.get("rows", []),
        "page": data.get("page", page or 1),
        "page_size": data.get("page_size", page_size or len(data.get("rows", []))),
        "has_more": data.get("has_more", data.get("truncated", False)),
    }


# OpenAI / 兼容接口的 tools 定义示例：
# 你可以在调用 chat/completions 时把下面这个结构放到 tools 字段中。
QUERY_DATABASE_TOOL_SPEC: Dict[str, Any] = {
    "type": "function",
    "function": {
        "name": "query_database",
        "description": "使用自然语言问题查询业务数据库，可返回多行记录、统计结果，支持分页。",
        "parameters": {
            "type": "object",
            "properties": {
                "natural_language_query": {
                    "type": "string",
                    "description": "用户的问题，例如：统计 2024 年每月订单数；或：查询最近 10 条登录日志。",
                },
                "page": {
                    "type": "integer",
                    "description": "结果页码，从 1 开始；不传则返回第一页或非分页结果。",
                },
                "page_size": {
                    "type": "integer",
                    "description": "每页大小；不传则使用默认值。",
                },
            },
            "required": ["natural_language_query"],
        },
    },
}

