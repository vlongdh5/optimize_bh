"""Kết nối ByteHouse dùng chung cho các script trong optimize_bh."""
import os
from pathlib import Path

from clickhouse_driver import Client
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def get_client(**settings) -> Client:
    return Client(
        host=os.environ["BYTEHOUSE_HOST"],
        port=int(os.environ["BYTEHOUSE_PORT"]),
        user=os.environ["BYTEHOUSE_USER"],
        password=os.environ["BYTEHOUSE_PASSWORD"],
        secure=True,
        connect_timeout=15,
        send_receive_timeout=600,
        settings={"virtual_warehouse": os.environ["VIRTUAL_WAREHOUSE"], **settings},
    )
