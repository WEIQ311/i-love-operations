from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional
import os

from dotenv import load_dotenv

load_dotenv()

DbDriver = Literal["postgresql", "mysql"]


@dataclass
class DbConfig:
    driver: DbDriver
    host: str
    port: int
    database: str
    user: str
    password: str

    @property
    def sqlalchemy_url(self) -> str:
        if self.driver == "postgresql":
            return (
                f"postgresql+psycopg2://{self.user}:{self.password}"
                f"@{self.host}:{self.port}/{self.database}"
            )
        elif self.driver == "mysql":
            return (
                f"mysql+pymysql://{self.user}:{self.password}"
                f"@{self.host}:{self.port}/{self.database}"
            )
        raise ValueError(f"Unsupported driver: {self.driver}")


@dataclass
class LlmConfig:
    api_base: str
    api_key: str
    model: str


@dataclass
class AgentConfig:
    db: DbConfig
    llm: LlmConfig
    max_rows: int = 200


def load_config_from_env(prefix: str = "DB_") -> AgentConfig:
    driver = os.getenv(f"{prefix}DRIVER", "postgresql")
    host = os.getenv(f"{prefix}HOST", "localhost")
    port = int(os.getenv(f"{prefix}PORT", "5432" if driver == "postgresql" else "3306"))
    database = os.getenv(f"{prefix}NAME", "")
    user = os.getenv(f"{prefix}USER", "")
    password = os.getenv(f"{prefix}PASSWORD", "")

    db_cfg = DbConfig(
        driver=driver, host=host, port=port, database=database, user=user, password=password
    )

    llm_api_base = os.getenv("LLM_API_BASE", "https://api.openai.com/v1")
    llm_api_key = os.getenv("LLM_API_KEY", "")
    llm_model = os.getenv("LLM_MODEL", "gpt-4.1-mini")

    if not llm_api_key:
        raise RuntimeError("环境变量 LLM_API_KEY 未设置，无法调用大模型。")

    llm_cfg = LlmConfig(api_base=llm_api_base, api_key=llm_api_key, model=llm_model)

    max_rows = int(os.getenv("AGENT_MAX_ROWS", "200"))

    return AgentConfig(db=db_cfg, llm=llm_cfg, max_rows=max_rows)
