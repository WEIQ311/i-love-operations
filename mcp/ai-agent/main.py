from __future__ import annotations

import argparse
from typing import List

from src_agent import build_default_agent


def _format_table(columns: List[str], rows: list[dict]) -> str:
    if not rows:
        return "（无结果）"
    col_widths = {c: max(len(c), *(len(str(r.get(c, ""))) for r in rows)) for c in columns}
    sep = " | "
    header = sep.join(c.ljust(col_widths[c]) for c in columns)
    line = "-+-".join("-" * col_widths[c] for c in columns)
    body_lines = []
    for r in rows:
        body_lines.append(sep.join(str(r.get(c, "")).ljust(col_widths[c]) for c in columns))
    return "\n".join([header, line, *body_lines])


def main() -> None:
    parser = argparse.ArgumentParser(description="NL2SQL 大模型数据库查询 Agent")
    parser.add_argument("-q", "--question", type=str, help="自然语言问题，例如：统计 2024 年每月订单量")
    args = parser.parse_args()

    question = args.question
    if not question:
        question = input("请输入查询问题（自然语言）：").strip()

    agent = build_default_agent()
    result = agent.ask(question)

    print("\n=== 生成的 SQL ===")
    print(result.sql)

    print("\n=== 查询结果（前若干行） ===")
    print(_format_table(result.data["columns"], result.data["rows"]))
    if result.data.get("truncated"):
        print("\n（结果已截断，如需更多行可调整环境变量 AGENT_MAX_ROWS）")


if __name__ == "__main__":
    main()

