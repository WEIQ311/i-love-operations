"""
Doris MCP + LangChain AI Query System
Intelligent database query system with business context analysis.
"""

import asyncio
import logging
from typing import Dict, Any, Optional
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain.chat_models import init_chat_model
from langchain.prompts import ChatPromptTemplate
from langchain_mcp_adapters.client import MultiServerMCPClient

# Configuration Constants
DEEPSEEK_API_KEY = "your_deepseek_api_key_here"
MODEL_NAME = "deepseek-chat"
MODEL_PROVIDER = "deepseek"
MCP_CONFIG = {
    "doris_mcp_server": {
        "transport": "streamable_http",
        "url": "http://localhost:3000/mcp"
    }
}


class PromptManager:
    """Business context prompt management for Doris AI assistant."""

    SYSTEM_PROMPT = """
🤖 你是基于Apache Doris数据库的专业AI问数系统，具备强大的数据分析和业务洞察能力。

核心职责：
1. 分析用户问题语境，理解业务需求
2. 精准调用Doris MCP Server工具执行查询
3. 提供深度业务语境分析和专业解释
4. 将技术数据转化为可执行的业务洞察

回答格式要求（必须包含以下结构）：
📈 查询结果：准确的数据查询结果，使用表格或图表符号展示
🔍 业务解读：数据背后的业务含义和趋势分析
💎 关键洞察：重要发现、异常点和数据亮点
🚀 行动建议：基于数据的具体可执行建议

展示风格：
- 使用📊📈📉等图表符号增强数据可视化效果
- 适当使用✅❌⚠️等状态符号标识重要信息
- 用🔥💪⭐等表情符号突出关键发现
- 保持专业、准确、有洞察力的分析风格
- 让数据"说话"，用生动的方式传达专业见解
    """.strip()

    @classmethod
    def enhance_query(cls, query: str) -> str:
        """Enhance user query with business context."""
        return f"{cls.SYSTEM_PROMPT}\n\n用户查询：{query}\n请执行查询并提供业务分析，包括数据洞察、业务影响和行动建议。"


class Config:
    """Application configuration management."""

    def __init__(self,
                 api_key: Optional[str] = None,
                 model: Optional[str] = None,
                 provider: Optional[str] = None,
                 mcp_config: Optional[Dict[str, Any]] = None) -> None:
        self.api_key = self._validate_api_key(api_key or DEEPSEEK_API_KEY)
        self.model = model or MODEL_NAME
        self.provider = provider or MODEL_PROVIDER
        self.mcp_config = mcp_config or MCP_CONFIG

    @staticmethod
    def _validate_api_key(key: str) -> str:
        """Validate API key configuration."""
        if not key or key == "your_deepseek_api_key_here":
            raise ValueError("Valid DeepSeek API key required")
        return key


class DorisMCPAgent:
    """Doris MCP Agent with intelligent business context analysis."""

    def __init__(self, config: Config) -> None:
        self.config = config
        self._mcp_client: Optional[MultiServerMCPClient] = None
        self._agent_executor: Optional[AgentExecutor] = None

    async def initialize(self) -> None:
        """Initialize MCP client and LangChain agent."""
        self._mcp_client = MultiServerMCPClient(self.config.mcp_config)

        tools = await self._mcp_client.get_tools()
        if not tools:
            raise RuntimeError("Failed to load tools from MCP server")

        llm = init_chat_model(
            model=self.config.model,
            model_provider=self.config.provider,
            api_key=self.config.api_key
        )

        prompt = ChatPromptTemplate.from_messages([
            ("system", PromptManager.SYSTEM_PROMPT),
            ("human", "{input}"),
            ("placeholder", "{agent_scratchpad}")
        ])

        agent = create_openai_tools_agent(llm, tools, prompt)
        self._agent_executor = AgentExecutor(
            agent=agent,
            tools=tools,
            verbose=True,
            max_iterations=3
        )

    async def run_interactive(self) -> None:
        """Start interactive chat session."""
        if not self._agent_executor:
            raise RuntimeError("Agent not initialized")

        print("\n" + "=" * 60)
        print("🤖 欢迎使用 Doris AI 问数系统 🤖")
        print("=" * 60)

        print("🔥 您可以这样问我：")
        print("   1️⃣  当前Doris有哪些库表？")
        print("   2️⃣  请帮我切换到tpch库并分析哪个客户下单最多")
        print("   3️⃣  等等等...")

        print("\n💬 输入您的问题开始分析，输入 'quit' 退出系统")
        print("=" * 60 + "\n")

        while True:
            try:
                query = input("You: ").strip()

                if query.lower() in {'quit', 'exit', 'q'}:
                    print("Goodbye!")
                    break

                if not query:
                    continue

                enhanced_query = PromptManager.enhance_query(query)
                result = await self._agent_executor.ainvoke({"input": enhanced_query})
                print(f"\nAI: {result['output']}\n")

            except KeyboardInterrupt:
                print("\nGoodbye!")
                break
            except Exception as e:
                print(f"Error: {e}")


async def main() -> None:
    """Application entry point."""
    logging.basicConfig(level=logging.WARNING)

    try:
        config = Config()
        agent = DorisMCPAgent(config)
        await agent.initialize()
        await agent.run_interactive()
    except Exception as e:
        print(f"Error: {e}")
        print("Please check the configuration section")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nInterrupted")
    except Exception as e:
        print(f"Startup failed: {e}")
