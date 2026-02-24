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
import logging
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from src_tool import query_database


LOG_DIR = Path(__file__).resolve().parent / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "mcp_server.log"


logger = logging.getLogger("ai_db_agent")
logger.setLevel(logging.INFO)
if not logger.handlers:
    file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    formatter = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s - %(message)s"
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)


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
    logger.info(
        "MCP call query_database_tool received: question=%r, page=%r, page_size=%r",
        natural_language_query,
        page,
        page_size,
    )

    try:
        logger.info("Step 1: invoke query_database")
        result = query_database(
            natural_language_query=natural_language_query,
            page=page,
            page_size=page_size,
        )

        # 粗略记录返回行数，便于排查问题
        rows = result.get("rows") if isinstance(result, dict) else None
        row_count = len(rows) if isinstance(rows, list) else "unknown"
        logger.info(
            "Step 2: query_database finished successfully, rows=%s", row_count
        )

        return result
    except Exception:
        logger.exception("query_database_tool failed with exception")
        raise


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


