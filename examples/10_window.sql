-- =====================================================================
-- 10장. 윈도우 함수 - 행을 유지한 채 집계/순위/이전 행 비교
-- =====================================================================

-- @ex 10-01 GROUP BY vs 윈도우 함수 - 행이 줄어들지 않는다
SELECT name, dept_id, salary,
       round(avg(salary) OVER ())              AS 전체평균,
       round(avg(salary) OVER (PARTITION BY dept_id)) AS 부서평균
FROM employees
WHERE dept_id IN (2, 4)
ORDER BY dept_id, salary DESC;

-- @ex 10-02 순위 함수 - ROW_NUMBER, RANK, DENSE_RANK 비교
SELECT name, stock,
       ROW_NUMBER() OVER (ORDER BY stock) AS row_number,
       RANK()       OVER (ORDER BY stock) AS rank,
       DENSE_RANK() OVER (ORDER BY stock) AS dense_rank
FROM products
WHERE stock <= 15            -- 재고가 적은 순서로 순위
ORDER BY stock, name;

-- @ex 10-03 그룹별 순위 - 부서별 연봉 순위
SELECT d.name AS 부서, e.name, e.salary,
       RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS 부서내순위
FROM employees e JOIN departments d ON e.dept_id = d.dept_id
WHERE e.dept_id IN (2, 4)
ORDER BY d.name, 부서내순위;

-- @ex 10-04 TOP-N per group - 분류별 가장 많이 팔린 상품 1개
SELECT 분류, 상품, 판매수량
FROM (
    SELECT c.name AS 분류, p.name AS 상품, sum(oi.quantity) AS 판매수량,
           ROW_NUMBER() OVER (PARTITION BY c.category_id
                              ORDER BY sum(oi.quantity) DESC, p.product_id) AS rn
    FROM order_items oi
    JOIN products p   ON oi.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    GROUP BY c.category_id, c.name, p.product_id, p.name
) t
WHERE rn = 1
ORDER BY 판매수량 DESC;

-- @ex 10-05 누적 합계 - 2026년 월별 매출과 누적 매출
WITH monthly AS (
    SELECT date_trunc('month', o.order_date)::date AS 월,
           sum(oi.quantity * oi.unit_price) AS 매출
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'CANCELLED' AND o.order_date >= '2026-01-01'
    GROUP BY 1
)
SELECT 월, 매출,
       sum(매출) OVER (ORDER BY 월) AS 누적매출,
       round(100.0 * 매출 / sum(매출) OVER (), 1) AS 비중
FROM monthly
ORDER BY 월;

-- @ex 10-06 LAG / LEAD - 전월 대비 증감률
WITH monthly AS (
    SELECT date_trunc('month', o.order_date)::date AS 월,
           sum(oi.quantity * oi.unit_price) AS 매출
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'CANCELLED' AND o.order_date >= '2026-01-01'
    GROUP BY 1
)
SELECT 월, 매출,
       LAG(매출) OVER (ORDER BY 월) AS 전월매출,
       round(100.0 * (매출 - LAG(매출) OVER (ORDER BY 월))
             / LAG(매출) OVER (ORDER BY 월), 1) AS 증감률
FROM monthly
ORDER BY 월;

-- @ex 10-07 고객별 직전 주문과의 간격 (재구매 주기)
SELECT customer_id, order_id, order_date::date,
       order_date::date - LAG(order_date::date) OVER w AS 이전주문후_일수
FROM orders
WHERE customer_id = 1
WINDOW w AS (PARTITION BY customer_id ORDER BY order_date)
ORDER BY order_date
LIMIT 6;

-- @ex 10-08 이동 평균 - 윈도우 프레임 (ROWS BETWEEN)
WITH daily AS (
    SELECT order_date::date AS d, count(*) AS cnt
    FROM orders WHERE order_date >= '2026-05-01'
    GROUP BY 1
)
SELECT d, cnt,
       round(avg(cnt) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS 이동평균3
FROM daily
ORDER BY d
LIMIT 8;

-- @ex 10-09 FIRST_VALUE / LAST_VALUE - 프레임을 전체로 지정해야 하는 이유
SELECT name, category_id, price,
       FIRST_VALUE(name) OVER w AS 최저가상품,
       LAST_VALUE(name)  OVER w AS 최고가상품
FROM products
WHERE category_id IN (4, 5)
WINDOW w AS (PARTITION BY category_id ORDER BY price
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);

-- @ex 10-10 NTILE / PERCENT_RANK - 고객을 구매액 기준 4개 그룹으로
WITH s AS (
    SELECT o.customer_id, sum(oi.quantity * oi.unit_price) AS total
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT customer_id, total,
       NTILE(4) OVER (ORDER BY total DESC) AS 분위,
       round(PERCENT_RANK() OVER (ORDER BY total)::numeric, 2) AS 백분위
FROM s
ORDER BY total DESC
LIMIT 8;

-- @ex 10-11 윈도우 함수는 WHERE 에서 쓸 수 없다 [error]
SELECT name, price FROM products
WHERE ROW_NUMBER() OVER (ORDER BY price DESC) <= 3;
