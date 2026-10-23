"""19-02 조회 결과 다루기와 파라미터 바인딩 (SQL 인젝션 방지)"""
from psycopg.rows import dict_row

from db import connect

with connect(row_factory=dict_row) as conn:      # 행을 dict 로 받기
    # 1) 여러 행 조회
    rows = conn.execute(
        "SELECT name, price FROM products WHERE category_id = %s ORDER BY price DESC",
        (6,),                                       # 값은 반드시 파라미터로 전달
    ).fetchall()
    print("[주변기기]")
    for r in rows:
        print(f"  {r['name']} : {r['price']:,}원")

    # 2) 이름 있는 파라미터
    row = conn.execute(
        "SELECT name, grade FROM customers WHERE city = %(city)s AND grade = %(grade)s",
        {"city": "서울", "grade": "VIP"},
    ).fetchone()
    print("\n[서울 VIP]", row)

    # 3) SQL 인젝션 - 사용자가 입력한 값이 악의적인 경우
    user_input = "' OR '1'='1"

    bad_sql = f"SELECT count(*) AS n FROM customers WHERE email = '{user_input}'"
    print("\n[나쁜 예] 문자열로 SQL 조립:", bad_sql)
    print("   → 조회된 고객 수:", conn.execute(bad_sql).fetchone()["n"], "(전체 고객이 노출!)")

    good = conn.execute("SELECT count(*) AS n FROM customers WHERE email = %s", (user_input,))
    print("[좋은 예] 파라미터 바인딩 → 조회된 고객 수:", good.fetchone()["n"])
