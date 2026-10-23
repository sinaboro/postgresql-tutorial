-- =====================================================================
-- 13장. 인덱스와 실행 계획 - 빠른 쿼리 만들기
--   실행 계획의 cost/시간 숫자는 PC 마다 다릅니다. 교안은 COSTS OFF 로 구조만 보여 줍니다.
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS big_orders;
RESET client_min_messages;

-- @ex 13-01 실습용 대용량 테이블 만들기 (100만 건)
SELECT setseed(0.42);                                  -- 난수 고정
CREATE TABLE big_orders AS
SELECT g                                               AS id,
       (random() * 99999)::int + 1                     AS customer_id,
       timestamp '2024-01-01' + random() * interval '900 days' AS order_date,
       (ARRAY['PAID','SHIPPED','DELIVERED','CANCELLED'])[1 + (random() * 3)::int] AS status,
       round((random() * 500000)::numeric, -2)        AS amount
FROM generate_series(1, 1000000) AS g;
ALTER TABLE big_orders ADD PRIMARY KEY (id);
ANALYZE big_orders;
SELECT count(*), pg_size_pretty(pg_total_relation_size('big_orders')) AS 크기 FROM big_orders;

-- @ex 13-02 인덱스가 없을 때 - Seq Scan (전체 테이블 읽기)
EXPLAIN (COSTS OFF)
SELECT * FROM big_orders WHERE customer_id = 12345;

-- @ex 13-03 EXPLAIN ANALYZE - 실제로 실행해서 읽은 행 수 확인
EXPLAIN (ANALYZE, BUFFERS OFF, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT * FROM big_orders WHERE customer_id = 12345;

-- @ex 13-04 B-tree 인덱스 생성 후 - Index/Bitmap Scan 으로 바뀐다
CREATE INDEX idx_big_orders_customer ON big_orders (customer_id);
EXPLAIN (ANALYZE, BUFFERS OFF, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT * FROM big_orders WHERE customer_id = 12345;

-- @ex 13-05 psql 의 \timing 으로 속도 비교 (숫자는 환경마다 다름)
-- \timing on
-- SELECT count(*) FROM big_orders WHERE customer_id = 12345;  -- 인덱스 O : 수 ms
-- DROP INDEX idx_big_orders_customer;
-- SELECT count(*) FROM big_orders WHERE customer_id = 12345;  -- 인덱스 X : 수십 ms
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'big_orders';

-- @ex 13-06 복합 인덱스 - 컬럼 순서가 중요하다 (왼쪽부터 사용)
CREATE INDEX idx_big_status_date ON big_orders (status, order_date);
EXPLAIN (COSTS OFF)
SELECT count(*) FROM big_orders
WHERE status = 'CANCELLED' AND order_date >= '2026-01-01';
-- 두 번째 컬럼만 조건으로 쓰면: 17 이하 버전은 인덱스를 거의 못 쓰고,
-- 18 부터는 선두 컬럼 값의 종류가 적을 때 skip scan 으로 활용할 수 있다
EXPLAIN (COSTS OFF)
SELECT count(*) FROM big_orders WHERE order_date >= '2026-06-01';

-- @ex 13-07 인덱스를 못 쓰는 경우 1 - 컬럼에 함수/연산을 씌우면
EXPLAIN (COSTS OFF)
SELECT * FROM big_orders WHERE customer_id + 0 = 12345;

-- @ex 13-08 표현식 인덱스 - 대소문자 무시 검색
CREATE INDEX idx_customers_lower_email ON customers (lower(email));
SET enable_seqscan = off;                 -- 작은 테이블이라 강제로 인덱스 사용을 확인
EXPLAIN (COSTS OFF)
SELECT * FROM customers WHERE lower(email) = 'minjun@example.com';
RESET enable_seqscan;

-- @ex 13-09 부분 인덱스 - 자주 찾는 일부 행만 인덱싱
CREATE INDEX idx_big_pending ON big_orders (order_date) WHERE status = 'PAID';
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS 크기
FROM pg_indexes WHERE tablename = 'big_orders' ORDER BY indexname;

-- @ex 13-10 LIKE 검색과 인덱스 - 앞부분 일치만 B-tree 가 도움
CREATE INDEX idx_products_name ON products (name text_pattern_ops);
SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT * FROM products WHERE name LIKE '스마트%';   -- 인덱스 가능
EXPLAIN (COSTS OFF) SELECT * FROM products WHERE name LIKE '%노트북';   -- 불가
RESET enable_seqscan;

-- @ex 13-11 JOIN 실행 계획 읽기 - Hash Join / Nested Loop
EXPLAIN (COSTS OFF)
SELECT c.name, count(*)
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.name;

-- @ex 13-12 외래 키 컬럼에는 인덱스를 직접 만들어야 한다
SELECT conrelid::regclass AS 테이블, conname AS 외래키
FROM pg_constraint WHERE contype = 'f' AND conrelid = 'orders'::regclass;
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

-- @ex 13-13 사용되지 않는 인덱스 찾기 (통계 뷰)
SELECT relname AS 테이블, indexrelname AS 인덱스, idx_scan AS 사용횟수
FROM pg_stat_user_indexes
WHERE relname = 'big_orders'
ORDER BY indexrelname;
