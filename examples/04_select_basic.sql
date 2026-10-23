-- =====================================================================
-- 04장. SELECT 기초 - 원하는 행과 열 골라내기
-- =====================================================================

-- @ex 04-01 필요한 컬럼만 고르기 + 별칭(AS)
SELECT name AS 상품명, price AS 가격, stock AS "재고 수량"
FROM products
LIMIT 5;

-- @ex 04-02 계산된 컬럼
SELECT name,
       price,
       price * 0.9         AS 할인가,
       price * stock       AS 재고금액
FROM products
WHERE category_id = 6;

-- @ex 04-03 DISTINCT - 중복 제거
SELECT DISTINCT city FROM customers ORDER BY city;
SELECT DISTINCT city, grade FROM customers WHERE city = '서울' ORDER BY grade;

-- @ex 04-04 WHERE + 비교 연산자
SELECT name, price FROM products WHERE price >= 1000000;
SELECT name, grade FROM customers WHERE grade <> 'BRONZE' AND city = '서울';

-- @ex 04-05 AND / OR 우선순위 - 괄호를 꼭 쓰자
-- (의도) 서울 또는 부산에 사는 VIP 고객
SELECT name, city, grade FROM customers
WHERE city = '서울' OR city = '부산' AND grade = 'VIP';      -- 잘못된 결과!
SELECT name, city, grade FROM customers
WHERE (city = '서울' OR city = '부산') AND grade = 'VIP';    -- 올바른 결과

-- @ex 04-06 IN, BETWEEN
SELECT name, city FROM customers WHERE city IN ('대구', '대전', '광주');
SELECT name, price FROM products WHERE price BETWEEN 30000 AND 60000 ORDER BY price;

-- @ex 04-07 LIKE / ILIKE - 패턴 검색 (% 는 0개 이상, _ 는 정확히 1글자)
SELECT name FROM products WHERE name LIKE '%노트북%';
SELECT name FROM customers WHERE name LIKE '김__';
SELECT name FROM products WHERE name ILIKE 'usb%';           -- 대소문자 무시

-- @ex 04-08 NULL 다루기 - = NULL 은 항상 실패한다
SELECT name, phone FROM customers WHERE phone = NULL;        -- 0건!
SELECT name, phone FROM customers WHERE phone IS NULL;
SELECT count(*) AS 전화번호있음 FROM customers WHERE phone IS NOT NULL;

-- @ex 04-09 NULL 과 연산하면 결과도 NULL
SELECT NULL = NULL AS 같은가, NULL + 1 AS 더하기, 'a' || NULL AS 연결,
       NULL IS NULL AS is_null,
       NULL IS DISTINCT FROM NULL AS 다른가;

-- @ex 04-10 ORDER BY - 정렬 (여러 기준, 내림차순)
SELECT name, grade, city FROM customers
ORDER BY grade, city DESC, name
LIMIT 8;

-- @ex 04-11 NULL 의 정렬 위치 지정 (NULLS FIRST / LAST)
SELECT name, birth_date FROM customers
ORDER BY birth_date DESC NULLS LAST
LIMIT 5;

-- @ex 04-12 LIMIT / OFFSET - 페이지 나누기 (한 페이지 5건, 2페이지)
SELECT product_id, name FROM products
ORDER BY product_id
LIMIT 5 OFFSET 5;

-- @ex 04-13 표준 문법 FETCH FIRST ... ROWS ONLY / WITH TIES
SELECT name, price FROM products
ORDER BY price DESC
FETCH FIRST 3 ROWS ONLY;
SELECT name, stock FROM products
ORDER BY stock
FETCH FIRST 1 ROWS WITH TIES;               -- 1등과 같은 값이면 함께 출력

-- @ex 04-14 날짜 조건 - 2026년 1분기 주문
SELECT order_id, customer_id, order_date, status
FROM orders
WHERE order_date >= '2026-01-01' AND order_date < '2026-04-01'
ORDER BY order_date
LIMIT 6;

-- @ex 04-15 SQL 실행 순서: FROM → WHERE → SELECT → ORDER BY → LIMIT
-- SELECT 에서 만든 별칭은 ORDER BY 에서는 쓸 수 있지만 WHERE 에서는 쓸 수 없다
SELECT name, price * stock AS 재고금액 FROM products ORDER BY 재고금액 DESC LIMIT 3;

-- @ex 04-16 WHERE 에서 SELECT 별칭을 쓰면 오류 [error]
SELECT name, price * stock AS 재고금액 FROM products WHERE 재고금액 > 1000000;
