# AI DB Agent（NL2SQL）

使用大模型将自然语言转换为 SQL，查询 MySQL / PostgreSQL 等关系型数据库中的数据，并以表格或 JSON 形式返回结果，适合作为*
*大模型工具（tool）或独立 API 服务**使用。

- **输入**：自然语言问题（中文/英文）+ 可选分页参数。
- **中间**：自动读取数据库 schema，调用 LLM 生成只读 SQL，并做安全校验。
- **输出**：SQL + 查询结果（支持明细、多条记录、统计聚合、分页）。

## 1. 环境准备（conda）

```bash
conda activate algo-workspace
cd /Users/admin/work/resource/ai-agent
pip install -r requirements.txt
```

## 2. 配置环境变量

在项目根目录创建 `.env` 文件，或直接通过 shell 导出环境变量。

**数据库配置（任选 MySQL 或 PostgreSQL）：**

```bash
# PostgreSQL 示例
export DB_DRIVER=postgresql
export DB_HOST=127.0.0.1
export DB_PORT=5432
export DB_NAME=your_db
export DB_USER=your_user
export DB_PASSWORD=your_password

# MySQL 示例
# export DB_DRIVER=mysql
# export DB_HOST=127.0.0.1
# export DB_PORT=3306
# export DB_NAME=your_db
# export DB_USER=your_user
# export DB_PASSWORD=your_password
```

**大模型配置（OpenAI 兼容接口示例）：**

```bash
export LLM_API_BASE=https://api.openai.com/v1
export LLM_API_KEY=sk-xxxxx
export LLM_MODEL=gpt-4.1-mini
```

可替换为任意兼容 `chat/completions` 的服务，只要 `api_base`、`api_key`、`model` 配置正确即可。

**可选参数：**

```bash
# 控制每次最多返回多少行数据（默认 200）
export AGENT_MAX_ROWS=200
```

## 3. 运行方式

### 3.1 命令行直接提问

```bash
python main.py -q "统计 2024 年每个月的订单数量和金额"
```

### 3.2 交互式输入

```bash
python main.py
# 按提示输入自然语言问题
```

### 3.3 启动 API 服务（推荐给大模型调用）

```bash
uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

启动后，大模型或其他服务可以通过 `POST http://<host>:8000/query` 调用本服务。

示例（curl）：

```bash
curl -X POST "http://127.0.0.1:8000/query" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "统计 2024 年每个月的订单数量和金额",
    "page": 1,
    "page_size": 50
  }'
```

返回 JSON 示例（结构固定，字段内容会随 SQL 变化）：

```json
{
  "question": "统计 2024 年每个月的订单数量和金额",
  "sql": "SELECT ...",
  "columns": [
    "month",
    "order_count",
    "amount"
  ],
  "rows": [
    {
      "month": "2024-01",
      "order_count": 123,
      "amount": 4567.89
    }
  ],
  "page": 1,
  "page_size": 50,
  "has_more": false
}
```

## 4. 安全策略说明

- 大模型只被允许生成 `SELECT` 开头的只读 SQL。
- 通过字符串规则过滤了 `INSERT/UPDATE/DELETE/DDL/事务控制` 等关键字。
- 禁止多条语句（包含额外 `;`）。
- 查询时限定最大返回行数 `AGENT_MAX_ROWS`，避免一次性拉取太多数据。

## 5. 代码结构概要

- `requirements.txt`：Python 依赖。
- `src_config.py`：加载环境变量、数据库与 LLM 配置。
- `src_db.py`：SQLAlchemy 封装（建连接、读取 schema、执行只读查询，支持分页包装）。
- `src_nl2sql.py`：NL2SQL 调用 LLM，做 SQL 安全校验（只允许 SELECT，禁止多语句等）。
- `src_agent.py`：`DbQueryAgent`，编排 schema -> NL2SQL -> 执行查询全流程，支持分页。
- `src_tool.py`：提供给大模型的统一 tool 入口 `query_database`，以及 `QUERY_DATABASE_TOOL_SPEC` 示例。
- `api.py`：基于 FastAPI 的 HTTP API 服务入口（`POST /query`）。
- `main.py`：命令行入口（本地调试方便）。
- `mcp_server.py`：基于 MCP Python SDK 的 MCP Server，暴露 `query_database_tool` 工具，供 MCP Host（如 Cursor）调用。
- `.cursor/mcp.json`：Cursor 项目级 MCP 配置，告诉 Cursor 如何拉起本地 MCP Server。

后续你可以在此基础上继续扩展，例如：

- 支持多数据库同时查询、路由到不同库。
- 增加对统计分析的二次解释（LLM 总结查询结果）。
- 做一个简单 Web UI 或接入你现有的服务。

## 6. 给大模型注册统一入口（function calling / tools）

如果你在上层还有一个“总 Agent”，可以把本项目暴露为一个 `query_database` 工具，供大模型自动调用。

`src_tool.py` 中已经提供了：

- Python 调用入口：`query_database(natural_language_query, page=None, page_size=None)`
- 对应的工具定义：`QUERY_DATABASE_TOOL_SPEC`

以 OpenAI 兼容接口为例，`tools` 中可以加入：

```python
from src_tool import QUERY_DATABASE_TOOL_SPEC

tools = [QUERY_DATABASE_TOOL_SPEC]
```

当模型选择调用 `query_database` 时，你在服务端按参数转调本项目的 `query_database` 函数即可，返回结果结构中已经包含：

- `columns` / `rows`：可直接展示或继续让模型做二次分析。
- `page` / `page_size` / `has_more`：可以驱动大模型/前端继续翻页或追加查询。

## 7. 常见问题（FAQ）

- **Q：数据库表结构经常变化，要改代码吗？**  
  **A：不需要。** 项目运行时会通过 SQLAlchemy 的 `inspect` 动态读取当前库的表和字段信息，并把这些 schema
  描述发给大模型，所以只要连接的是最新的数据库，就能自动适配。

- **Q：统计类问题（如分组、汇总）也能处理吗？**  
  **A：可以。** 大模型会根据自然语言问题和 schema 生成对应的 `GROUP BY / COUNT / SUM / AVG` 等 SQL，结果通过
  `columns + rows` 返回，你可以直接展示或再交给大模型做二次解释。

- **Q：分页是怎么做的？**  
  **A：** 如果传入 `page` 和 `page_size`，底层会把 LLM 生成的 SQL 包一层子查询，加上 `LIMIT/OFFSET`，并多取一行判断是否还有下一页，结果通过
  `page/page_size/has_more` 返回。

- **Q：如何只在内网调用，不暴露数据库细节？**  
  **A：** 推荐在内网部署本项目的 API 服务（`uvicorn api:app ...`），只暴露 `/query` 这个接口给上层大模型服务，数据库连接信息只存在当前服务的
  `.env`/环境变量中，对外部是不可见的。

## 8. 作为 MCP 服务使用（上架到 Cursor 等 Host）

项目已经内置了一个标准的 MCP Server：`mcp_server.py`，基于官方 Python SDK（`mcp` 包），既可以本地 stdio 方式被 Cursor
拉起，也可以作为远程 HTTP MCP 服务暴露。

- **工具入口**：`query_database_tool`（内部复用 `src_tool.query_database`）
- **传输方式**：stdio（适配 Cursor、Claude Desktop 等）

### 8.1 在 Cursor 中启用本地 MCP Server

项目下已经提供了 `.cursor/mcp.json`，内容类似：

```json
{
  "mcpServers": {
    "ai-db-agent": {
      "command": "python",
      "args": [
        "mcp_server.py"
      ],
      "env": {
        "PYTHONUNBUFFERED": "1"
      }
    }
  }
}
```

只要你在 Cursor 中打开本项目目录：

1. 确保已经安装依赖并配置好 `.env`。
2. Cursor 会自动读取项目内的 `.cursor/mcp.json`，并在 MCP 面板中显示 `ai-db-agent`。
3. 启用后，Cursor 内的大模型就可以直接调用该 MCP Server 暴露的 `query_database_tool` 工具。

### 8.2 作为全局 MCP Server（可选）

如果希望在所有项目中都能使用这个服务，可以把 `mcp_server.py` 和相应配置加入全局 `~/.cursor/mcp.json` 中，例如：

```json
{
  "mcpServers": {
    "ai-db-agent": {
      "command": "python",
      "args": [
        "/Users/admin/work/resource/ai-agent/mcp_server.py"
      ]
    }
  }
}
```

> 注意：全局配置下，数据库和 LLM 的环境变量依然由 `.env` 或系统环境变量控制，建议在运行用户下统一配置。

### 8.3 启动远程 HTTP MCP 服务

如果你希望其他机器上的 MCP Host（或自研 Agent）通过 HTTP 连接，可以这样启动：

```bash
cd /Users/admin/work/resource/ai-agent
conda activate algo-workspace

# 默认以 HTTP 方式启动 MCP（0.0.0.0:8000）
python mcp_server.py http
```

可选环境变量（覆盖默认 host/port）：

```bash
export MCP_HTTP_HOST=0.0.0.0
export MCP_HTTP_PORT=9000
python mcp_server.py http
```

此时会在 `http://MCP_HTTP_HOST:MCP_HTTP_PORT/mcp` 暴露一个 HTTP MCP 端点，你可以用 MCP Inspector 或其他支持
HTTP/streamable-http 的 Host 进行连接测试。

### 8.4 上架 / 调试 MCP Server 的推荐流程

1. 安装依赖：`pip install -r requirements.txt`（包含 `mcp`）。
2. 配置 `.env`：填好数据库和 LLM 相关变量，并确认能通过 `python main.py` 正常查询。
3. 如需本地（stdio）方式给 Cursor 用：直接在 Cursor 打开项目并启用 `ai-db-agent`。
4. 如需远程 HTTP MCP：在服务器上运行 `python mcp_server.py http`，再用 MCP Inspector / 远程 Host 连接
   `http://host:port/mcp`。


