from __future__ import annotations

from typing import Tuple
import re
import requests

from src_config import LlmConfig

SYSTEM_PROMPT = """
你是一个资深数据分析师和高级 SQL 工程师。
用户会给出一个自然语言问题，以及当前数据库的 schema 信息。
请根据 schema 只生成一条安全的只读 SQL（只能使用 SELECT），用于在数据库中查询答案。

必须严格遵守以下要求：
- SQL 必须是完整的 SELECT 语句，至少包含 FROM 子句，例如：SELECT ... FROM some_table ...
- 严格只使用 SELECT 查询，禁止 INSERT/UPDATE/DELETE/DDL 等写操作。
- 不要使用事务控制语句（BEGIN/COMMIT/ROLLBACK）。
- 如无必要，不要使用子查询和复杂 join。
- 尽量限制返回行数，例如使用 LIMIT。
- 输出时只返回一条可以直接执行的 SQL，不要解释，不要加反引号或代码块，不要返回只有 “SELECT” 这类不完整语句。
"""


def _call_llm(cfg: LlmConfig, schema_summary: str, question: str) -> str:
    payload = {
        "model": cfg.model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"数据库 schema 如下：\n{schema_summary}\n\n用户问题：{question}\n\n请直接给出一条 SQL：",
            },
        ],
        "temperature": 0.1,
    }

    headers = {"Authorization": f"Bearer {cfg.api_key}", "Content-Type": "application/json"}
    resp = requests.post(f"{cfg.api_base}/chat/completions", json=payload, headers=headers, timeout=60)
    resp.raise_for_status()
    data = resp.json()
    content = data["choices"][0]["message"]["content"]
    return content.strip()


def is_safe_readonly_sql(sql: str) -> bool:
    s = sql.strip().strip(";").lower()
    if not s.startswith("select"):
        return False
    # 要求必须有 FROM 子句，避免只返回裸 SELECT 导致包装分页时语法错误
    if " from " not in f" {s} ":
        return False
    forbidden = [
        " insert ",
        " update ",
        " delete ",
        " drop ",
        " alter ",
        " create ",
        " truncate ",
        " merge ",
        " grant ",
        " revoke ",
        " commit ",
        " rollback ",
    ]
    for token in forbidden:
        if token in s:
            return False
    if ";" in sql.strip(";"):
        return False
    return True


def generate_sql(cfg: LlmConfig, schema_summary: str, question: str) -> Tuple[str, str]:
    """
    返回 (raw_llm_output, cleaned_sql)
    """
    raw = _call_llm(cfg, schema_summary, question)

    # 去掉可能的代码块包装
    code_block = re.search(r"```sql(.*?)```", raw, flags=re.S | re.I)
    if code_block:
        candidate = code_block.group(1).strip()
    else:
        candidate = raw.strip()

    # 取第一行作为 SQL 核心，防止模型偶尔加解释
    lines = [l for l in candidate.splitlines() if l.strip()]
    if not lines:
        raise ValueError("LLM 未返回有效 SQL。")
    sql = lines[0].strip()

    # 过滤明显无效的 SQL，例如只有 "select" 或太短的语句
    if len(sql) < 10:
        raise ValueError(f"LLM 返回的 SQL 过于简短或无效：{sql!r}")

    if not is_safe_readonly_sql(sql):
        raise ValueError(f"生成的 SQL 不安全或非只读：{sql}")

    return raw, sql
