from __future__ import annotations

from typing import List, Dict, Any
from pathlib import Path

from sqlalchemy import create_engine, text, inspect
from sqlalchemy.engine import Engine

from src_config import DbConfig

BASE_DIR = Path(__file__).resolve().parent
METADATA_DIR = BASE_DIR / "temp"


def create_db_engine(cfg: DbConfig) -> Engine:
    return create_engine(cfg.sqlalchemy_url, pool_pre_ping=True, future=True)


def _metadata_file_path(engine: Engine) -> Path:
    """
    根据数据库 driver、host、port、database 生成唯一的元数据文件路径。
    形如：
        temp/mysql_172.16.70.243_3306_ry_plus_cloud_2x_fz.schema.txt
    """
    url = engine.url
    driver = url.get_backend_name() or "unknown"
    host = (url.host or "localhost").replace(":", "_")
    port = str(url.port or "").replace(":", "_")
    database = (url.database or "").replace("/", "_").replace(":", "_")
    filename = f"{driver}_{host}_{port}_{database}.schema.txt"
    return METADATA_DIR / filename


def get_schema_summary(engine: Engine, max_tables: int = 50, use_cache: bool = True) -> str:
    """
    获取当前数据库的 schema 摘要。

    - 默认会先从 temp 目录下按「driver_host_port_db」命名的文件读取缓存；
    - 如果不存在，则在线扫描元数据（表 / 字段），并把结果写入缓存文件，方便后续直接给大模型使用。
    """
    metadata_path = _metadata_file_path(engine)

    if use_cache and metadata_path.exists():
        return metadata_path.read_text(encoding="utf-8")

    inspector = inspect(engine)
    tables = inspector.get_table_names()[:max_tables]
    lines: List[str] = []
    for table in tables:
        # 表注释（很多 MySQL 库会写中文表名）
        table_comment = ""
        try:
            tc = inspector.get_table_comment(table)  # 返回 {"text": "...", ...}
            table_comment = (tc or {}).get("text") or ""
        except Exception:
            table_comment = ""

        cols = inspector.get_columns(table)
        col_desc_list: List[str] = []
        for c in cols:
            col_name = c["name"]
            col_type = str(c.get("type"))
            col_comment = c.get("comment") or ""
            if col_comment:
                col_desc_list.append(f"{col_name} {col_type} /* {col_comment} */")
            else:
                col_desc_list.append(f"{col_name} {col_type}")

        col_str = ", ".join(col_desc_list)

        if table_comment:
            lines.append(f"Table {table} /* {table_comment} */ ({col_str})")
        else:
            lines.append(f"Table {table}({col_str})")

    summary = "\n".join(lines)

    if use_cache:
        METADATA_DIR.mkdir(parents=True, exist_ok=True)
        metadata_path.write_text(summary, encoding="utf-8")

    return summary


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
