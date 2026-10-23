"""setup/02_seed.sql 생성기.

난수 시드를 고정하므로 몇 번을 실행해도 같은 데이터가 만들어진다.
교안의 실행 결과가 이 데이터에 맞춰져 있으므로, 이 파일을 바꾸면 교안도 다시 빌드해야 한다.
    python tools/gen_seed.py
"""
import json
import random
from datetime import date, datetime, timedelta
from pathlib import Path

rnd = random.Random(2026)
OUT = Path(__file__).resolve().parent.parent / "setup" / "02_seed.sql"


def q(v):
    """파이썬 값을 SQL 리터럴로."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, (dict, list)):
        return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'"
    return "'" + str(v).replace("'", "''") + "'"


def insert(table, cols, rows):
    lines = [f"INSERT INTO {table} ({', '.join(cols)}) VALUES"]
    body = [f"    ({', '.join(q(v) for v in r)})" for r in rows]
    return "\n".join(lines) + "\n" + ",\n".join(body) + ";\n"


departments = [
    (1, "경영지원", "서울"),
    (2, "영업", "서울"),
    (3, "마케팅", "서울"),
    (4, "개발", "판교"),
    (5, "물류", "인천"),
]

# (id, name, dept, manager, title, salary(만원), hire_date, email)
employees = [
    (1, "김대표", 1, None, "대표이사", 15000, "2015-03-02", "ceo@shop.kr"),
    (2, "이영업", 2, 1, "영업본부장", 9800, "2016-07-01", "sales.lee@shop.kr"),
    (3, "박마케", 3, 1, "마케팅팀장", 8200, "2017-01-09", "mkt.park@shop.kr"),
    (4, "최개발", 4, 1, "CTO", 12000, "2016-02-15", "cto.choi@shop.kr"),
    (5, "정물류", 5, 1, "물류팀장", 7600, "2018-05-21", "log.jung@shop.kr"),
    (6, "강민수", 2, 2, "영업대리", 5200, "2020-03-02", "minsu.kang@shop.kr"),
    (7, "조은지", 2, 2, "영업과장", 6300, "2019-08-12", "eunji.cho@shop.kr"),
    (8, "윤서준", 2, 7, "영업사원", 4100, "2023-01-02", "seojun.yoon@shop.kr"),
    (9, "장하늘", 3, 3, "마케터", 4800, "2021-06-14", "haneul.jang@shop.kr"),
    (10, "임도윤", 4, 4, "백엔드 개발자", 6800, "2019-11-04", "doyoon.lim@shop.kr"),
    (11, "한지민", 4, 4, "프론트엔드 개발자", 6100, "2020-09-01", "jimin.han@shop.kr"),
    (12, "오세훈", 4, 10, "주니어 개발자", 4500, "2024-01-15", "sehoon.oh@shop.kr"),
    (13, "서유나", 5, 5, "물류 담당", 4200, "2022-04-04", "yuna.seo@shop.kr"),
    (14, "신동현", 2, 7, "영업사원", 4000, "2024-07-01", "donghyun.shin@shop.kr"),
    (15, "권나래", None, None, "인턴", 2800, "2026-03-02", None),
]

cities = ["서울", "부산", "인천", "대구", "대전", "광주", "수원"]
# (id, name, email, phone, city, grade, birth_date, joined_at)
customers = [
    (1, "김민준", "minjun@example.com", "010-1234-0001", "서울", "VIP", "1988-02-11", "2024-01-05 10:12:00"),
    (2, "이서연", "seoyeon@example.com", "010-1234-0002", "부산", "GOLD", "1992-07-23", "2024-01-19 14:30:00"),
    (3, "박도윤", "doyoon@example.com", None, "서울", "SILVER", "1985-11-02", "2024-02-03 09:00:00"),
    (4, "최지우", "jiwoo@example.com", "010-1234-0004", "대구", "BRONZE", "1999-04-17", "2024-02-28 20:45:00"),
    (5, "정하은", "haeun@example.com", "010-1234-0005", "인천", "GOLD", "1995-09-30", "2024-03-14 11:20:00"),
    (6, "강시우", "siwoo@example.com", "010-1234-0006", "서울", "SILVER", "1979-12-25", "2024-04-01 08:05:00"),
    (7, "조수아", "sua@example.com", None, "광주", "BRONZE", "2001-01-08", "2024-04-22 16:40:00"),
    (8, "윤지호", "jiho@example.com", "010-1234-0008", "대전", "VIP", "1983-06-12", "2024-05-09 13:15:00"),
    (9, "장예린", "yerin@example.com", "010-1234-0009", "수원", "SILVER", "1997-03-03", "2024-06-17 19:00:00"),
    (10, "임준서", "junseo@example.com", "010-1234-0010", "서울", "GOLD", "1990-10-10", "2024-07-07 07:07:00"),
    (11, "한소율", "soyul@example.com", "010-1234-0011", "부산", "BRONZE", None, "2024-08-21 22:10:00"),
    (12, "오건우", "gunwoo@example.com", "010-1234-0012", "서울", "SILVER", "1987-05-05", "2024-09-02 12:00:00"),
    (13, "서지아", "jia@example.com", None, "인천", "BRONZE", "2003-08-19", "2024-10-11 15:25:00"),
    (14, "신우진", "woojin@example.com", "010-1234-0014", "대구", "GOLD", "1993-02-14", "2024-11-30 10:50:00"),
    (15, "권하린", "harin@example.com", "010-1234-0015", "서울", "BRONZE", "1998-12-01", "2025-01-15 09:30:00"),
    (16, "황민재", "minjae@example.com", "010-1234-0016", "수원", "SILVER", "1981-07-27", "2025-03-03 17:45:00"),
    (17, "안채원", "chaewon@example.com", "010-1234-0017", "광주", "BRONZE", "2000-11-11", "2025-05-20 21:00:00"),
    (18, "송현우", "hyunwoo@example.com", "010-1234-0018", "대전", "BRONZE", "1994-04-04", "2025-08-08 08:08:00"),
    (19, "류다은", "daeun@example.com", "010-1234-0019", "서울", "BRONZE", "2002-06-06", "2026-02-10 10:10:00"),
    (20, "홍길동", "gildong@example.com", None, "부산", "BRONZE", None, "2026-05-01 12:00:00"),
]

categories = [
    (1, "전자제품", None), (2, "의류", None), (3, "식품", None),
    (4, "노트북", 1), (5, "스마트폰", 1), (6, "주변기기", 1),
    (7, "남성의류", 2), (8, "여성의류", 2),
    (9, "간식", 3), (10, "음료", 3),
    (11, "게이밍 노트북", 4),
]

# (id, category, name, price, stock, is_active, attrs, created_at)
products = [
    (1, 4, "울트라북 14", 1290000, 15, True, {"brand": "한빛", "color": "silver", "weight_kg": 1.2, "ram_gb": 16}, "2024-01-02"),
    (2, 4, "비즈니스 노트북 15", 990000, 22, True, {"brand": "누리", "color": "black", "weight_kg": 1.7, "ram_gb": 8}, "2024-01-02"),
    (3, 11, "게이밍 노트북 X17", 2490000, 6, True, {"brand": "한빛", "color": "black", "weight_kg": 2.6, "ram_gb": 32, "gpu": "RTX"}, "2024-03-10"),
    (4, 5, "스마트폰 S25", 1150000, 30, True, {"brand": "누리", "color": "blue", "storage_gb": 256}, "2024-02-01"),
    (5, 5, "스마트폰 미니", 690000, 18, True, {"brand": "가온", "color": "white", "storage_gb": 128}, "2024-02-01"),
    (6, 6, "무선 마우스", 29000, 120, True, {"brand": "가온", "color": "black", "wireless": True}, "2024-01-05"),
    (7, 6, "기계식 키보드", 89000, 45, True, {"brand": "한빛", "color": "white", "wireless": False, "switch": "갈축"}, "2024-01-05"),
    (8, 6, "27인치 모니터", 329000, 12, True, {"brand": "누리", "size_inch": 27, "resolution": "QHD"}, "2024-04-15"),
    (9, 6, "USB-C 허브", 45000, 0, True, {"brand": "가온", "ports": 7}, "2024-05-01"),
    (10, 7, "남성 셔츠", 39000, 60, True, {"color": "navy", "sizes": ["M", "L", "XL"]}, "2024-03-01"),
    (11, 7, "남성 청바지", 59000, 40, True, {"color": "blue", "sizes": ["30", "32", "34"]}, "2024-03-01"),
    (12, 8, "여성 원피스", 79000, 25, True, {"color": "red", "sizes": ["S", "M"]}, "2024-03-20"),
    (13, 8, "여성 니트", 49000, 35, True, {"color": "beige", "sizes": ["S", "M", "L"]}, "2024-09-01"),
    (14, 9, "수제 쿠키 세트", 15000, 200, True, {"brand": "달콤", "weight_g": 500}, "2024-02-10"),
    (15, 9, "견과류 믹스", 22000, 150, True, {"brand": "고소", "weight_g": 800}, "2024-02-10"),
    (16, 10, "콜드브루 원액", 18000, 80, True, {"brand": "달콤", "volume_ml": 1000}, "2024-06-01"),
    (17, 10, "유기농 녹차", 12000, 90, True, {"brand": "초록", "count": 50}, "2024-06-01"),
    (18, 6, "노트북 거치대", 35000, 70, True, None, "2024-07-01"),
    (19, 7, "남성 정장 세트", 299000, 5, False, {"color": "charcoal"}, "2024-08-01"),
    (20, 10, "탄산수 24입", 16000, 0, False, {"brand": "초록", "volume_ml": 500}, "2025-01-10"),
]
price = {p[0]: p[3] for p in products}

# ---------------- 주문 생성 ----------------
sales_emps = [6, 7, 8, 14, None, None]          # 담당 영업사원 (None = 온라인 주문)
orderable = list(range(1, 19))                   # 19, 20 번 상품은 한 번도 주문되지 않음
weights = [3, 4, 1, 4, 3, 9, 6, 3, 2, 6, 5, 4, 4, 8, 7, 7, 6, 5]
buyers = list(range(1, 19))                      # 19, 20 번 고객은 주문 이력 없음
buyer_w = [9, 6, 5, 2, 6, 4, 2, 8, 3, 6, 2, 4, 2, 5, 3, 3, 2, 2]

start = datetime(2025, 1, 1)
end = datetime(2026, 6, 30)
span = (end - start).days
orders, items = [], []
oid = 0
for _ in range(120):
    oid += 1
    cid = rnd.choices(buyers, buyer_w)[0]
    joined = datetime.fromisoformat(customers[cid - 1][7])
    d0 = max(start, joined)
    d = d0 + timedelta(days=rnd.randint(0, (end - d0).days), hours=rnd.randint(8, 22),
                       minutes=rnd.randint(0, 59))
    age = (end - d).days
    if age < 3:
        status = rnd.choice(["PENDING", "PAID"])
    elif age < 10:
        status = rnd.choice(["PAID", "SHIPPED"])
    else:
        status = rnd.choices(["DELIVERED", "CANCELLED"], [9, 1])[0]
    city = customers[cid - 1][4] if rnd.random() < 0.85 else rnd.choice(cities)
    orders.append((oid, cid, rnd.choice(sales_emps), d.strftime("%Y-%m-%d %H:%M:%S"), status, city))
    picked = set()
    for _ in range(rnd.choices([1, 2, 3, 4], [4, 3, 2, 1])[0]):
        pid = rnd.choices(orderable, weights)[0]
        if pid in picked:
            continue
        picked.add(pid)
        qty = rnd.choices([1, 2, 3, 5], [6, 3, 1, 1])[0]
        up = price[pid]
        if rnd.random() < 0.15:                  # 가끔 10% 할인 판매
            up = int(round(up * 0.9, -2))
        items.append((oid, pid, qty, up))

# 주문 날짜순으로 order_id 다시 매기기 (교안에서 읽기 쉽도록)
orders.sort(key=lambda o: o[3])
remap = {o[0]: i + 1 for i, o in enumerate(orders)}
orders = [(remap[o[0]],) + o[1:] for o in orders]
items = sorted(((remap[i[0]],) + i[1:] for i in items), key=lambda r: (r[0], r[1]))

# ---------------- 리뷰 ----------------
comments = {
    5: ["정말 만족합니다!", "배송도 빠르고 품질 최고", "재구매 의사 있어요", "가성비 훌륭합니다"],
    4: ["좋아요. 추천합니다", "무난하게 쓰고 있습니다", "가격 대비 괜찮아요"],
    3: ["보통이에요", "기대보다는 평범합니다"],
    2: ["배송이 너무 늦었어요", "생각보다 별로네요"],
    1: ["불량품이 왔습니다", "환불 요청했어요"],
}
reviews, seen = [], set()
delivered = {o[0]: o for o in orders if o[4] == "DELIVERED"}
for it in items:
    o = delivered.get(it[0])
    if not o or rnd.random() > 0.35 or (it[1], o[1]) in seen:
        continue
    seen.add((it[1], o[1]))
    r = rnd.choices([5, 4, 3, 2, 1], [5, 4, 2, 1, 1])[0]
    when = datetime.fromisoformat(o[3]) + timedelta(days=rnd.randint(3, 20))
    text = rnd.choice(comments[r]) if rnd.random() < 0.9 else None
    reviews.append((it[1], o[1], r, text, when.strftime("%Y-%m-%d %H:%M:%S")))
reviews.sort(key=lambda r: r[4])
reviews = [(i + 1,) + r for i, r in enumerate(reviews)]

# ---------------- 출력 ----------------
parts = [
    "-- =====================================================================",
    "-- 실습용 쇼핑몰(shop) 샘플 데이터  (tools/gen_seed.py 로 생성 - 직접 수정하지 마세요)",
    "-- =====================================================================",
    "",
    insert("departments", ["dept_id", "name", "location"], departments),
    insert("employees", ["emp_id", "name", "dept_id", "manager_id", "job_title", "salary", "hire_date", "email"], employees),
    insert("customers", ["customer_id", "name", "email", "phone", "city", "grade", "birth_date", "joined_at"], customers),
    insert("categories", ["category_id", "name", "parent_id"], categories),
    insert("products", ["product_id", "category_id", "name", "price", "stock", "is_active", "attrs", "created_at"], products),
    insert("orders", ["order_id", "customer_id", "emp_id", "order_date", "status", "ship_city"], orders),
    insert("order_items", ["order_id", "product_id", "quantity", "unit_price"], items),
    insert("reviews", ["review_id", "product_id", "customer_id", "rating", "content", "created_at"], reviews),
    "-- IDENTITY 시퀀스를 현재 최댓값 다음부터 시작하도록 맞춘다",
    "DO $$",
    "BEGIN",
]
for t, c in [("departments", "dept_id"), ("employees", "emp_id"), ("customers", "customer_id"),
             ("categories", "category_id"), ("products", "product_id"), ("orders", "order_id"),
             ("reviews", "review_id")]:
    parts.append(f"    PERFORM setval(pg_get_serial_sequence('{t}', '{c}'), (SELECT max({c}) FROM {t}));")
parts.append("END $$;\n\nANALYZE;\n")
OUT.write_text("\n".join(parts), encoding="utf-8")
print(f"{OUT}: orders={len(orders)} items={len(items)} reviews={len(reviews)}")
