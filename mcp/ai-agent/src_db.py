from __future__ import annotations

from typing import List, Dict, Any

from sqlalchemy import create_engine, text, inspect
from sqlalchemy.engine import Engine

from src_config import DbConfig


def create_db_engine(cfg: DbConfig) -> Engine:
    return create_engine(cfg.sqlalchemy_url, pool_pre_ping=True, future=True)


def get_schema_summary(engine: Engine, max_tables: int = 50) -> str:
    inspector = inspect(engine)
    tables = inspector.get_table_names()[:max_tables]
    lines: List[str] = []
    for table in tables:
        cols = inspector.get_columns(table)
        col_str = ", ".join(f"{c['name']} {str(c.get('type'))}" for c in cols)
        lines.append(f"Table {table}({col_str})")
    return "\n".join(lines)


def run_safe_select(
    engine: Engine,
    sql: str,
    max_rows: int = 200,
    page: int | None = None,
    page_size: int | None = None,
) -> Dict[str, Any]:
    """
    执行只读 SELECT。

    - 默认模式：不分页，最多返回 max_rows 行。
    - 分页模式：传入 page 和 page_size，内部自动包一层子查询并加 LIMIT/OFFSET。
    """
    sql_clean = sql.strip().rstrip(";")

    if page is not None and page_size is not None:
        page = max(page, 1)
        page_size = max(page_size, 1)
        offset = (page - 1) * page_size
        # 再多取一行，用于判断是否还有下一页
        limit = page_size + 1
        wrapped_sql = f"SELECT * FROM ({sql_clean}) AS subq LIMIT :limit OFFSET :offset"
        with engine.connect() as conn:
            result = conn.execute(text(wrapped_sql), {"limit": limit, "offset": offset})
            rows = result.fetchall()
            columns = list(result.keys())
        has_more = len(rows) > page_size
        rows = rows[:page_size]
        data_rows = [dict(zip(columns, row)) for row in rows]
        return {
            "columns": columns,
            "rows": data_rows,
            "truncated": has_more,
            "page": page,
            "page_size": page_size,
            "has_more": has_more,
        }

    with engine.connect() as conn:
        result = conn.execute(text(sql_clean))
        rows = result.fetchmany(max_rows + 1)
        columns = list(result.keys())
    truncated = len(rows) > max_rows
    rows = rows[:max_rows]
    data = [dict(zip(columns, row)) for row in rows]
    return {"columns": columns, "rows": data, "truncated": truncated}

