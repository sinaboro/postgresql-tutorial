-- =====================================================================
-- 12장. 뷰, 머티리얼라이즈드 뷰, 시퀀스, 스키마
-- =====================================================================

-- @ex 12-01 뷰 만들기 - 자주 쓰는 조인을 저장
CREATE VIEW v_order_detail AS
SELECT o.order_id, o.order_date, o.status,
       c.customer_id, c.name AS customer_name,
       p.product_id, p.name AS product_name,
       oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS amount
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id;

SELECT order_id, customer_name, product_name, amount
FROM v_order_detail
WHERE order_id = 2;

-- @ex 12-02 뷰는 테이블처럼 쓸 수 있다
SELECT customer_name, sum(amount) AS 총액
FROM v_order_detail
WHERE status = 'DELIVERED'
GROUP BY customer_name
ORDER BY 총액 DESC
LIMIT 3;

-- @ex 12-03 뷰는 데이터를 저장하지 않는다 - 원본이 바뀌면 바로 반영
UPDATE order_items SET quantity = 10 WHERE order_id = 1 AND product_id = 13;
SELECT order_id, product_name, quantity, amount FROM v_order_detail WHERE order_id = 1;

-- @ex 12-04 보안 목적의 뷰 - 민감한 컬럼 감추기
CREATE VIEW v_customer_public AS
SELECT customer_id, name, city, grade FROM customers;      -- email, phone 제외
SELECT * FROM v_customer_public LIMIT 3;

-- @ex 12-05 단순 뷰는 수정도 가능 + WITH CHECK OPTION
CREATE VIEW v_seoul_customers AS
SELECT customer_id, name, city, email FROM customers WHERE city = '서울'
WITH CHECK OPTION;
UPDATE v_seoul_customers SET name = '김민준(수정)' WHERE customer_id = 1;
SELECT customer_id, name FROM customers WHERE customer_id = 1;

-- @ex 12-06 CHECK OPTION 위반 - 뷰 조건을 벗어나는 수정 [error]
UPDATE v_seoul_customers SET city = '부산' WHERE customer_id = 1;

-- @ex 12-07 머티리얼라이즈드 뷰 - 결과를 저장해 두는 뷰
CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT date_trunc('month', order_date)::date AS month,
       sum(amount) AS sales
FROM v_order_detail
WHERE status <> 'CANCELLED'
GROUP BY 1;
SELECT * FROM mv_monthly_sales WHERE month >= '2026-04-01' ORDER BY month;

-- @ex 12-08 머티리얼라이즈드 뷰는 REFRESH 해야 최신화된다
INSERT INTO orders (customer_id, order_date, status, ship_city)
VALUES (1, '2026-06-30 10:00', 'PAID', '서울') RETURNING order_id;
INSERT INTO order_items VALUES (currval(pg_get_serial_sequence('orders', 'order_id')), 3, 1, 2490000);
SELECT * FROM mv_monthly_sales WHERE month = '2026-06-01';   -- 아직 그대로
REFRESH MATERIALIZED VIEW mv_monthly_sales;
SELECT * FROM mv_monthly_sales WHERE month = '2026-06-01';   -- 반영됨

-- @ex 12-09 시퀀스 직접 다루기
CREATE SEQUENCE invoice_seq START WITH 1000 INCREMENT BY 10;
SELECT nextval('invoice_seq') AS 첫번째, nextval('invoice_seq') AS 두번째;
SELECT currval('invoice_seq') AS 현재값;
SELECT 'INV-' || to_char(current_date, 'YYYYMMDD') || '-' || nextval('invoice_seq') AS 송장번호;

-- @ex 12-10 SERIAL 과 IDENTITY 비교 (IDENTITY 가 표준이자 권장)
CREATE TABLE t_serial   (id SERIAL PRIMARY KEY, v TEXT);
CREATE TABLE t_identity (id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, v TEXT);
INSERT INTO t_serial (id, v) VALUES (1, '직접 지정 가능');     -- 시퀀스는 모른 채 1 이 들어감

-- @ex 12-11 SERIAL 의 중복 키 사고와 IDENTITY ALWAYS 의 보호 [error]
INSERT INTO t_serial (v) VALUES ('자동');                       -- 시퀀스가 1 을 줘서 충돌!
INSERT INTO t_identity (id, v) VALUES (1, '직접 지정');          -- ALWAYS 는 막아 준다

-- @ex 12-12 스키마 - 테이블을 묶는 폴더(네임스페이스)
CREATE SCHEMA report;
CREATE TABLE report.daily_kpi (kpi_date DATE PRIMARY KEY, sales NUMERIC);
INSERT INTO report.daily_kpi VALUES ('2026-06-30', 2490000);
SELECT * FROM report.daily_kpi;
SHOW search_path;
SELECT schema_name FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg_%' AND schema_name <> 'information_schema'
ORDER BY 1;
