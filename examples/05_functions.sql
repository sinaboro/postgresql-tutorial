-- =====================================================================
-- 05장. 내장 함수 - 문자열, 숫자, 날짜, 형변환, 조건식
-- =====================================================================

-- @ex 05-01 문자열 함수 1 - 길이, 대소문자, 자르기
SELECT length('PostgreSQL')        AS 길이,
       length('데이터베이스')      AS 한글길이,
       upper('sql'), lower('SQL'),
       substring('PostgreSQL' FROM 1 FOR 8) AS 앞8글자,
       left('010-1234-5678', 3)    AS 왼쪽3,
       right('010-1234-5678', 4)   AS 오른쪽4;

-- @ex 05-02 문자열 함수 2 - 연결, 공백 제거, 바꾸기, 채우기
SELECT concat('김', '대', '철')            AS concat,
       concat_ws('-', '2026', '10', '23')   AS concat_ws,
       '[' || trim('   공백   ') || ']'     AS trim,
       replace('010-1234-5678', '-', '')    AS replace,
       lpad('42', 5, '0')                   AS lpad,
       split_part('a@test.com', '@', 2)     AS 도메인,
       position('@' IN 'a@test.com')        AS 위치;

-- @ex 05-03 문자열 함수 활용 - 이메일 아이디와 전화번호 마스킹
SELECT name,
       split_part(email, '@', 1)                           AS 아이디,
       left(phone, 4) || '****' || right(phone, 5)         AS 마스킹번호
FROM customers
WHERE phone IS NOT NULL
LIMIT 4;

-- @ex 05-04 숫자 함수
SELECT round(1234.5678, 2) AS round2,
       round(1234.5678, -2) AS round_m2,
       trunc(1234.5678, 1) AS trunc1,
       ceil(4.1) AS ceil, floor(4.9) AS floor,
       abs(-7) AS abs, mod(17, 5) AS mod, 17 % 5 AS 나머지,
       power(2, 8) AS power, sqrt(144) AS sqrt;

-- @ex 05-05 정수 나눗셈 주의 - 하나라도 실수/NUMERIC 이면 소수가 나온다
SELECT 7 / 2 AS 정수끼리, 7 / 2.0 AS 실수포함, 7::numeric / 2 AS 형변환,
       round(7::numeric / 3, 2) AS 반올림;

-- @ex 05-06 형변환 - CAST 와 :: 연산자
SELECT CAST('123' AS INTEGER) + 1    AS cast,
       '2026-10-23'::date + 7        AS 일주일뒤,
       123::text || '번'             AS 숫자를문자로,
       '3.14'::numeric * 2           AS 문자를숫자로,
       to_char(1234567, 'FM9,999,999') || '원' AS 천단위;

-- @ex 05-07 형변환 실패 [error]
SELECT 'abc'::integer;

-- @ex 05-08 현재 날짜와 시간
SELECT current_date, current_time(0), now()::timestamp(0) AS now,
       current_date - 1 AS 어제;

-- @ex 05-09 날짜 계산 - INTERVAL, 날짜 빼기, age()
SELECT date '2026-10-23' + interval '1 month'        AS 한달뒤,
       timestamp '2026-10-23 09:00' + interval '90 minutes' AS 구십분뒤,
       date '2026-12-25' - date '2026-10-23'         AS 크리스마스까지_일,
       age(date '2026-10-23', date '1990-05-15')     AS 나이;

-- @ex 05-10 날짜에서 부분 추출 - EXTRACT, date_part, date_trunc
SELECT order_id, order_date,
       EXTRACT(YEAR FROM order_date)    AS 연,
       EXTRACT(MONTH FROM order_date)   AS 월,
       EXTRACT(DOW FROM order_date)     AS 요일번호,   -- 0=일요일
       date_trunc('month', order_date)  AS 월초
FROM orders
WHERE order_id <= 3;

-- @ex 05-11 날짜 서식 지정 - to_char / to_date
SELECT to_char(order_date, 'YYYY-MM-DD')      AS 날짜,
       to_char(order_date, 'YYYY"년" MM"월" DD"일" HH24:MI') AS 한글서식,
       to_char(order_date, 'FMDay')            AS 요일
FROM orders WHERE order_id = 1;
SELECT to_date('2026/10/23', 'YYYY/MM/DD')    AS to_date,
       to_timestamp('20261023 1530', 'YYYYMMDD HH24MI') AS to_timestamp;

-- @ex 05-12 고객 나이 계산
SELECT name, birth_date,
       EXTRACT(YEAR FROM age(date '2026-10-23', birth_date)) AS 만나이
FROM customers
WHERE birth_date IS NOT NULL
ORDER BY birth_date
LIMIT 5;

-- @ex 05-13 CASE - 조건에 따라 다른 값 (검색 CASE)
SELECT name, price,
       CASE
           WHEN price >= 1000000 THEN '고가'
           WHEN price >= 100000  THEN '중가'
           ELSE '저가'
       END AS 가격대
FROM products
WHERE product_id IN (1, 5, 8, 14);

-- @ex 05-14 CASE - 값 비교형 (단순 CASE)
SELECT order_id, status,
       CASE status
           WHEN 'DELIVERED' THEN '배송완료'
           WHEN 'CANCELLED' THEN '취소'
           WHEN 'SHIPPED'   THEN '배송중'
           ELSE '처리중'
       END AS 상태
FROM orders
ORDER BY order_id DESC
LIMIT 5;

-- @ex 05-15 NULL 처리 함수 - COALESCE, NULLIF
SELECT name, COALESCE(phone, '(번호 없음)') AS phone
FROM customers WHERE customer_id IN (2, 3, 7);
-- NULLIF(a, b): a = b 이면 NULL → 0 으로 나누기 방지
SELECT 100 / NULLIF(0, 0) AS 안전한나눗셈;

-- @ex 05-16 GREATEST / LEAST
SELECT GREATEST(3, 7, 5) AS 최대, LEAST(3, 7, 5) AS 최소,
       GREATEST(price - 50000, 0) AS 쿠폰적용가
FROM products WHERE product_id = 6;
