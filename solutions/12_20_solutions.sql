-- =====================================================================
-- 실습 문제 정답 : 12장(뷰) ~ 20장(종합)
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS wallet, wallet_log;
RESET client_min_messages;

-- @ex 12-Q1 상품명, 분류명, 판매수량, 평균평점을 보여 주는 뷰 v_product_summary 를 만들고 판매수량 상위 3개를 조회하세요
CREATE VIEW v_product_summary AS
SELECT p.product_id, p.name, c.name AS category,
       COALESCE((SELECT sum(quantity) FROM order_items oi WHERE oi.product_id = p.product_id), 0) AS sold_qty,
       (SELECT round(avg(rating), 2) FROM reviews r WHERE r.product_id = p.product_id) AS avg_rating
FROM products p JOIN categories c ON c.category_id = p.category_id;
SELECT name, category, sold_qty, avg_rating FROM v_product_summary ORDER BY sold_qty DESC LIMIT 3;

-- @ex 12-Q2 등급별 고객 수와 총구매액을 담은 머티리얼라이즈드 뷰를 만들고 조회하세요
CREATE MATERIALIZED VIEW mv_grade_sales AS
SELECT c.grade, count(DISTINCT c.customer_id) AS customers, sum(oi.quantity * oi.unit_price) AS sales
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.grade;
SELECT * FROM mv_grade_sales ORDER BY sales DESC;

-- @ex 13-Q1 orders 에서 (customer_id, order_date) 복합 인덱스를 만들고, 고객 8번의 최근 주문 3건 조회 계획을 확인하세요
CREATE INDEX idx_orders_cust_date ON orders (customer_id, order_date DESC);
SET enable_seqscan = off;
EXPLAIN (COSTS OFF)
SELECT order_id, order_date FROM orders WHERE customer_id = 8 ORDER BY order_date DESC LIMIT 3;
RESET enable_seqscan;

-- @ex 13-Q2 다음 조건 중 일반 B-tree 인덱스(email)를 쓸 수 없는 것은? 표현식 인덱스로 해결하세요: WHERE upper(email) = 'JIHO@EXAMPLE.COM'
CREATE INDEX idx_customers_upper_email ON customers (upper(email));
SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT name FROM customers WHERE upper(email) = 'JIHO@EXAMPLE.COM';
RESET enable_seqscan;

-- @ex 14-Q1 wallet(id, balance≥0) 에서 1번→2번으로 7,000원 이체를 트랜잭션으로 처리하되 잔액이 부족하면 전체 취소되는 것을 확인하세요 [error]
CREATE TABLE wallet (id INT PRIMARY KEY, balance INT NOT NULL CHECK (balance >= 0));
INSERT INTO wallet VALUES (1, 5000), (2, 0);
BEGIN;
UPDATE wallet SET balance = balance + 7000 WHERE id = 2;
UPDATE wallet SET balance = balance - 7000 WHERE id = 1;    -- 실패
COMMIT;                                                       -- → ROLLBACK
SELECT * FROM wallet ORDER BY id;

-- @ex 15-Q1 상품 id 를 받아 '상품명 (분류명)' 문자열을 돌려주는 함수 product_label 을 만드세요
CREATE FUNCTION product_label(p_id INT) RETURNS TEXT
LANGUAGE sql STABLE AS $$
    SELECT p.name || ' (' || c.name || ')'
    FROM products p JOIN categories c USING (category_id)
    WHERE p.product_id = p_id;
$$;
SELECT product_label(3), product_label(14);

-- @ex 15-Q2 wallet 잔액이 바뀔 때마다 wallet_log(id, before, after, at)에 기록하는 트리거를 만드세요
CREATE TABLE wallet_log (wallet_id INT, before INT, after INT, at TIMESTAMP DEFAULT now());
CREATE FUNCTION trg_wallet_log() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO wallet_log (wallet_id, before, after) VALUES (OLD.id, OLD.balance, NEW.balance);
    RETURN NEW;
END $$;
CREATE TRIGGER wallet_audit AFTER UPDATE OF balance ON wallet
FOR EACH ROW EXECUTE FUNCTION trg_wallet_log();
UPDATE wallet SET balance = balance + 1000 WHERE id = 1;
SELECT wallet_id, before, after FROM wallet_log;

-- @ex 16-Q1 attrs 에 'wireless' 키가 true 인 상품과, 브랜드별 상품 수를 구하세요
SELECT name FROM products WHERE attrs @> '{"wireless": true}';
SELECT attrs ->> 'brand' AS brand, count(*) FROM products
WHERE attrs ? 'brand' GROUP BY 1 ORDER BY 2 DESC, 1;

-- @ex 16-Q2 각 상품의 사이즈 목록(attrs.sizes)을 행으로 펼쳐 사이즈별 상품 수를 구하세요
SELECT size, count(*) AS 상품수
FROM products, jsonb_array_elements_text(attrs -> 'sizes') AS size
GROUP BY size ORDER BY 상품수 DESC, size;

-- @ex 20-Q1 2025년 하반기에 구매했지만 2026년 상반기에 구매하지 않은 '이탈 고객' 명단을 만드세요 (취소 제외)
SELECT c.customer_id, c.name FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.status <> 'CANCELLED'
              AND o.order_date >= '2025-07-01' AND o.order_date < '2026-01-01')
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.status <> 'CANCELLED'
              AND o.order_date >= '2026-01-01' AND o.order_date < '2026-07-01')
ORDER BY c.customer_id;

-- @ex 20-Q2 분류별 매출 1위 고객(가장 많이 산 고객)을 구하세요 (최상위 분류 기준: 전자제품/의류/식품)
WITH top_cat AS (
    SELECT c.category_id, COALESCE(p2.category_id, p1.category_id, c.category_id) AS root
    FROM categories c
    LEFT JOIN categories p1 ON p1.category_id = c.parent_id
    LEFT JOIN categories p2 ON p2.category_id = p1.parent_id
), s AS (
    SELECT t.root, o.customer_id, sum(oi.quantity * oi.unit_price) AS sales
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN top_cat t      ON t.category_id = p.category_id
    WHERE o.status <> 'CANCELLED'
    GROUP BY t.root, o.customer_id
)
SELECT rc.name AS 대분류, cu.name AS 고객, s.sales AS 구매액
FROM (SELECT *, RANK() OVER (PARTITION BY root ORDER BY sales DESC) AS rk FROM s) s
JOIN categories rc ON rc.category_id = s.root
JOIN customers cu  ON cu.customer_id = s.customer_id
WHERE rk = 1 ORDER BY s.root;
