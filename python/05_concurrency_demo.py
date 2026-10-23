"""19-05 (14장 보충) 두 세션이 동시에 일할 때 - 격리 수준, 갱신 손실, 데드락

psql 창 두 개로 하던 실험을 커넥션 두 개(A, B)로 재현한다.
"""
import threading
import time

import psycopg

from db import connect


def setup():
    with connect() as c:
        c.execute("DROP TABLE IF EXISTS demo_acc")
        c.execute("CREATE TABLE demo_acc (id INT PRIMARY KEY, balance INT NOT NULL)")
        c.execute("INSERT INTO demo_acc VALUES (1, 1000), (2, 1000)")


def balance(conn, id_=1):
    return conn.execute("SELECT balance FROM demo_acc WHERE id = %s", (id_,)).fetchone()[0]


print("① READ COMMITTED - 다른 세션이 커밋한 값이 바로 보인다")
setup()
with connect() as a, connect(autocommit=True) as b:
    print("   A 첫 조회 :", balance(a))
    b.execute("UPDATE demo_acc SET balance = 500 WHERE id = 1")      # B 가 수정 후 자동 커밋
    print("   A 재조회 :", balance(a), "(같은 트랜잭션인데 값이 바뀜 = Non-repeatable read)")

print("\n② REPEATABLE READ - 트랜잭션 시작 시점의 스냅샷을 계속 본다")
setup()
with connect() as a, connect(autocommit=True) as b:
    a.isolation_level = psycopg.IsolationLevel.REPEATABLE_READ
    print("   A 첫 조회 :", balance(a))
    b.execute("UPDATE demo_acc SET balance = 500 WHERE id = 1")
    print("   A 재조회 :", balance(a), "(B 의 변경이 보이지 않음)")
    try:
        a.execute("UPDATE demo_acc SET balance = balance - 100 WHERE id = 1")
    except psycopg.errors.SerializationFailure as e:
        print("   A 가 같은 행 수정 시도 →", e.diag.message_primary)

print("\n③ 갱신 손실(Lost Update) - 읽고 → 앱에서 계산 → 쓰기")
setup()
with connect() as a, connect() as b:
    va = balance(a)                     # A: 1000 읽음
    vb = balance(b)                     # B: 1000 읽음
    a.execute("UPDATE demo_acc SET balance = %s WHERE id = 1", (va - 300,)); a.commit()
    b.execute("UPDATE demo_acc SET balance = %s WHERE id = 1", (vb - 200,)); b.commit()
    print("   기대값 500, 실제값", balance(a), "→ A 의 출금 300 이 사라짐!")

print("\n④ 해결 - SELECT ... FOR UPDATE 로 먼저 잠그기")
setup()
with connect() as a, connect() as b:
    va = a.execute("SELECT balance FROM demo_acc WHERE id = 1 FOR UPDATE").fetchone()[0]

    def session_b():
        vb = b.execute("SELECT balance FROM demo_acc WHERE id = 1 FOR UPDATE").fetchone()[0]
        b.execute("UPDATE demo_acc SET balance = %s WHERE id = 1", (vb - 200,))
        b.commit()

    t = threading.Thread(target=session_b)
    t.start()
    time.sleep(0.5)                     # B 는 A 가 커밋할 때까지 대기한다
    print("   B 대기 중? :", t.is_alive())
    a.execute("UPDATE demo_acc SET balance = %s WHERE id = 1", (va - 300,))
    a.commit()
    t.join()
    print("   최종 잔액 :", balance(a), "(정상)")

print("\n⑤ 데드락 - 서로 상대가 잠근 행을 기다리면 PostgreSQL 이 한쪽을 강제 취소")
setup()
with connect() as a, connect() as b:
    a.execute("UPDATE demo_acc SET balance = balance - 1 WHERE id = 1")   # A: 1번 잠금
    b.execute("UPDATE demo_acc SET balance = balance - 1 WHERE id = 2")   # B: 2번 잠금
    errors = []

    def session_b():
        try:
            b.execute("UPDATE demo_acc SET balance = balance + 1 WHERE id = 1")  # A 를 기다림
            b.commit()
        except psycopg.errors.DeadlockDetected as e:
            errors.append(("B", e.diag.message_primary))
            b.rollback()

    t = threading.Thread(target=session_b)
    t.start()
    time.sleep(0.3)
    try:
        a.execute("UPDATE demo_acc SET balance = balance + 1 WHERE id = 2")      # B 를 기다림 → 교착
        a.commit()
    except psycopg.errors.DeadlockDetected as e:
        errors.append(("A", e.diag.message_primary))
        a.rollback()
    t.join()
    for who, msg in errors:
        print(f"   세션 {who} 취소됨 :", msg)
    print("   → 해결책: 여러 행을 잠글 때는 항상 같은 순서(예: id 오름차순)로 잠근다")

with connect() as c:
    c.execute("DROP TABLE demo_acc")
