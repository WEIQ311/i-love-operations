from __future__ import annotations

"""
MCP Server：将 query_database 能力暴露为 MCP tool。

- 本地 / Cursor：默认使用 stdio 传输（适用于 Cursor / Claude 等 MCP Host）。
- 远程 / HTTP：可选择使用 streamable-http 传输，对外暴露 HTTP MCP 端点。

用法示例：
- 本地（stdio，给 Cursor 用）：
    python mcp_server.py
- 远程 HTTP（默认 0.0.0.0:8000）：
    python mcp_server.py http
"""

from typing import Any, Dict, Optional
import sys
import os

from mcp.server.fastmcp import FastMCP

from src_tool import query_database


mcp = FastMCP("ai-db-agent", json_response=True)


@mcp.tool()
def query_database_tool(
    natural_language_query: str,
    page: Optional[int] = None,
    page_size: Optional[int] = None,
) -> Dict[str, Any]:
    """
    使用自然语言问题查询业务数据库，可返回多行记录、统计结果，支持分页。

    - natural_language_query: 自然语言问题，例如「统计 2024 年每月订单数」。
    - page: 页码（从 1 开始，可选）。
    - page_size: 每页大小（可选）。
    """
    return query_database(
        natural_language_query=natural_language_query,
        page=page,
        page_size=page_size,
    )


if __name__ == "__main__":
    # 默认使用 stdio 传输，使其可以被 Cursor / Claude 等 Host 拉起。
    # 如果命令行第一个参数是 "http"，则使用 HTTP 传输，对外暴露 MCP 端点。
    transport = "stdio"
    if len(sys.argv) > 1 and sys.argv[1].lower() in {"http", "http-server"}:
        transport = "streamable-http"

    # 可选：通过环境变量覆盖 HTTP host / port
    host = os.getenv("MCP_HTTP_HOST", "0.0.0.0")
    port = int(os.getenv("MCP_HTTP_PORT", "8000"))

    if transport == "streamable-http":
        mcp.run(transport="streamable-http", host=host, port=port)
    else:
        mcp.run()


