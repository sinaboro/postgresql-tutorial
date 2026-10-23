"""19-03 INSERT, 여러 건 입력, 트랜잭션 (commit / rollback)"""
import psycopg

from db import connect

with connect() as conn:
    conn.execute("DROP TABLE IF EXISTS py_memo")
    conn.execute("""
        CREATE TABLE py_memo (
            id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            content TEXT NOT NULL CHECK (length(content) <= 20)
        )""")
    conn.commit()            # psycopg 는 기본적으로 트랜잭션을 열어 둔다 → commit 필요!

    # 1) 한 건 넣고 생성된 id 받기
    new_id = conn.execute("INSERT INTO py_memo (content) VALUES (%s) RETURNING id",
                          ("첫 번째 메모",)).fetchone()[0]
    conn.commit()
    print("새 메모 id:", new_id)

    # 2) 여러 건 한 번에
    with conn.cursor() as cur:
        cur.executemany("INSERT INTO py_memo (content) VALUES (%s)",
                        [("둘",), ("셋",), ("넷",)])
    conn.commit()

    # 3) 트랜잭션 블록 - 안에서 예외가 나면 블록 전체가 롤백된다
    try:
        with conn.transaction():
            conn.execute("INSERT INTO py_memo (content) VALUES ('정상 메모')")
            conn.execute("INSERT INTO py_memo (content) VALUES (%s)", ("너무 긴 메모" * 10,))
    except psycopg.errors.CheckViolation as e:
        print("오류 발생 → 롤백:", e.diag.message_primary)

    rows = conn.execute("SELECT id, content FROM py_memo ORDER BY id").fetchall()
    print("최종 메모:", rows)
    conn.execute("DROP TABLE py_memo")
    conn.commit()
