"""19-01 접속하고 첫 쿼리 실행하기"""
from db import connect

# with 블록을 벗어나면 커넥션이 자동으로 닫힌다
with connect() as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT current_database(), current_user, version()")
        db, user, version = cur.fetchone()
        print("DB      :", db)
        print("USER    :", user)
        print("VERSION :", version.split(",")[0])

        cur.execute("SELECT count(*) FROM customers")
        print("고객 수 :", cur.fetchone()[0])
