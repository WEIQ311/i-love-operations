from __future__ import annotations

from typing import Optional

from fastapi import FastAPI
from pydantic import BaseModel

from src_tool import query_database  # 复用你已有的统一入口


class QueryRequest(BaseModel):
    natural_language_query: str
    page: Optional[int] = None
    page_size: Optional[int] = None


app = FastAPI(title="AI DB Agent API", version="1.0.0")


@app.post("/query")
async def query(req: QueryRequest):
    """
    大模型 / 业务服务都可以直接调用的统一查询接口。
    """
    result = query_database(
        natural_language_query=req.natural_language_query,
        page=req.page,
        page_size=req.page_size,
    )
    # 这里直接返回 dict，FastAPI 会自动转为 JSON
    return result
