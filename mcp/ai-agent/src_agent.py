from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional

from src_config import AgentConfig, load_config_from_env
from src_db import create_db_engine, get_schema_summary, run_safe_select
from src_nl2sql import generate_sql


@dataclass
class AgentResult:
    question: str
    sql: str
    raw_llm_output: str
    data: Dict[str, Any]


class DbQueryAgent:
    def __init__(self, config: AgentConfig) -> None:
        self.config = config
        self.engine = create_db_engine(config.db)

    def ask(
        self,
        question: str,
        page: Optional[int] = None,
        page_size: Optional[int] = None,
    ) -> AgentResult:
        schema = get_schema_summary(self.engine)
        raw_llm_output, sql = generate_sql(self.config.llm, schema, question)
        data = run_safe_select(
            self.engine,
            sql,
            max_rows=self.config.max_rows,
            page=page,
            page_size=page_size,
        )
        return AgentResult(question=question, sql=sql, raw_llm_output=raw_llm_output, data=data)


def build_default_agent() -> DbQueryAgent:
    cfg = load_config_from_env()
    return DbQueryAgent(cfg)

