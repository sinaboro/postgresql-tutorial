-- =====================================================================
-- 09장. 집합 연산과 CTE(WITH) - 재귀 쿼리까지
-- =====================================================================

-- @ex 09-01 UNION / UNION ALL - 결과 합치기
SELECT city FROM customers WHERE grade = 'VIP'
UNION                                         -- 중복 제거
SELECT ship_city FROM orders WHERE order_id <= 3;
SELECT city FROM customers WHERE grade = 'VIP'
UNION ALL                                     -- 중복 유지 (더 빠름)
SELECT ship_city FROM orders WHERE order_id <= 3;

-- @ex 09-02 INTERSECT / EXCEPT - 교집합, 차집합
-- 2025년에도 2026년에도 주문한 고객
SELECT customer_id FROM orders WHERE order_date <  '2026-01-01'
INTERSECT
SELECT customer_id FROM orders WHERE order_date >= '2026-01-01'
ORDER BY 1;
-- 2025년에는 주문했지만 2026년에는 주문하지 않은 고객 (이탈 고객)
SELECT customer_id FROM orders WHERE order_date <  '2026-01-01'
EXCEPT
SELECT customer_id FROM orders WHERE order_date >= '2026-01-01'
ORDER BY 1;

-- @ex 09-03 집합 연산 규칙 - 컬럼 수와 타입이 맞아야 한다 [error]
SELECT name, city FROM customers
UNION
SELECT name FROM employees;

-- @ex 09-04 CTE(WITH) - 쿼리에 이름 붙이기
WITH customer_sales AS (
    SELECT o.customer_id, sum(oi.quantity * oi.unit_price) AS total
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'CANCELLED'
    GROUP BY o.customer_id
)
SELECT c.name, cs.total
FROM customer_sales cs JOIN customers c ON c.customer_id = cs.customer_id
WHERE cs.total > (SELECT avg(total) FROM customer_sales)
ORDER BY cs.total DESC;

-- @ex 09-05 CTE 여러 개 연결하기 - 2026년 상반기 분류별 매출 비중
WITH sales AS (
    SELECT p.category_id, oi.quantity * oi.unit_price AS amount
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    WHERE o.status <> 'CANCELLED'
      AND o.order_date >= '2026-01-01' AND o.order_date < '2026-07-01'
),
by_cat AS (
    SELECT category_id, sum(amount) AS amount FROM sales GROUP BY category_id
)
SELECT c.name, b.amount,
       round(100.0 * b.amount / (SELECT sum(amount) FROM by_cat), 1) AS 비중
FROM by_cat b JOIN categories c ON c.category_id = b.category_id
ORDER BY b.amount DESC;

-- @ex 09-06 재귀 CTE 기초 - 1부터 5까지
WITH RECURSIVE nums(n) AS (
    SELECT 1                       -- 시작(앵커)
    UNION ALL
    SELECT n + 1 FROM nums         -- 반복(재귀)
    WHERE n < 5                    -- 종료 조건
)
SELECT n FROM nums;

-- @ex 09-07 재귀 CTE - 조직도 (상사→부하 계층)
WITH RECURSIVE org AS (
    SELECT emp_id, name, job_title, manager_id, 1 AS depth, name::text AS path
    FROM employees WHERE manager_id IS NULL AND dept_id IS NOT NULL
    UNION ALL
    SELECT e.emp_id, e.name, e.job_title, e.manager_id, o.depth + 1,
           o.path || ' > ' || e.name
    FROM employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT repeat('    ', depth - 1) || name AS 조직도, job_title, depth
FROM org
ORDER BY path;

-- @ex 09-08 재귀 CTE - 분류 트리 경로 (게이밍 노트북의 전체 경로)
WITH RECURSIVE tree AS (
    SELECT category_id, name, parent_id, name::text AS full_path
    FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, c.parent_id, t.full_path || ' > ' || c.name
    FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT category_id, full_path FROM tree WHERE category_id IN (4, 6, 11) ORDER BY category_id;

-- @ex 09-09 [심화] generate_series 로 빈 날짜 채우기 - 2026년 6월 중순 일자별 주문수
SELECT d::date AS 날짜, count(o.order_id) AS 주문수
FROM generate_series('2026-06-12'::date, '2026-06-21'::date, interval '1 day') AS d
LEFT JOIN orders o ON o.order_date::date = d::date
GROUP BY d
ORDER BY d;

-- @ex 09-10 [심화] 데이터 변경 CTE - 삭제한 행을 다른 테이블로 옮기기
CREATE TABLE orders_archive (LIKE orders);
WITH moved AS (
    DELETE FROM orders
    WHERE status = 'CANCELLED' AND order_date < '2025-03-01'
    RETURNING *
)
INSERT INTO orders_archive SELECT * FROM moved;
SELECT order_id, order_date, status FROM orders_archive;
