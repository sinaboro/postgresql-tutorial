"""접속 정보를 한 곳에서 관리한다.

환경변수 DATABASE_URL 이 있으면 그것을, 없으면 로컬 기본값을 쓴다.
    (Windows)  set DATABASE_URL=postgresql://postgres:비밀번호@localhost:5432/shop
    (macOS)    export DATABASE_URL=postgresql://postgres:비밀번호@localhost:5432/shop
비밀번호를 코드에 직접 적어 깃에 올리지 않도록 주의!
"""
import os

import psycopg

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/shop")


def connect(**kwargs):
    return psycopg.connect(DATABASE_URL, **kwargs)
