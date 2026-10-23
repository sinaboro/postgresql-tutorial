-- =====================================================================
-- 20장. 종합 프로젝트 - 쇼핑몰 매출 분석 리포트
--   지금까지 배운 JOIN, 집계, CTE, 윈도우 함수, 뷰를 모두 사용합니다.
-- =====================================================================
SET client_min_messages = warning;
DROP VIEW IF EXISTS v_sales CASCADE;
RESET client_min_messages;

-- @ex 20-01 분석용 기본 뷰 - 취소 제외 판매 라인
CREATE VIEW v_sales AS
SELECT o.order_id, o.customer_id, o.emp_id, o.order_date,
       date_trunc('month', o.order_date)::date AS order_month,
       oi.product_id, p.category_id, oi.quantity,
       oi.quantity * oi.unit_price AS amount
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.status <> 'CANCELLED';
SELECT count(*) AS 판매라인, count(DISTINCT order_id) AS 주문수 FROM v_sales;

-- @ex 20-02 핵심 KPI - 매출, 주문수, 구매고객수, 객단가(AOV)
SELECT sum(amount)                                AS 총매출,
       count(DISTINCT order_id)                   AS 주문수,
       count(DISTINCT customer_id)                AS 구매고객수,
       round(sum(amount) / count(DISTINCT order_id)) AS 객단가
FROM v_sales;

-- @ex 20-03 전년 동월 대비(YoY) 매출 성장률 - 2026년 상반기
WITH m AS (
    SELECT order_month, sum(amount) AS sales FROM v_sales GROUP BY order_month
)
SELECT to_char(cur.order_month, 'YYYY-MM') AS 월,
       prev.sales AS 전년동월, cur.sales AS 당월,
       round(100.0 * (cur.sales - prev.sales) / prev.sales, 1) AS yoy
FROM m cur
LEFT JOIN m prev ON prev.order_month = cur.order_month - interval '1 year'
WHERE cur.order_month >= '2026-01-01'
ORDER BY cur.order_month;

-- @ex 20-04 RFM 분석 - 최근성(Recency), 빈도(Frequency), 금액(Monetary)
WITH base AS (
    SELECT customer_id,
           date '2026-07-01' - max(order_date)::date AS recency_days,
           count(DISTINCT order_id)                  AS frequency,
           sum(amount)                               AS monetary
    FROM v_sales GROUP BY customer_id
), scored AS (
    SELECT *,
           NTILE(3) OVER (ORDER BY recency_days DESC) AS r,   -- 최근일수록 3점
           NTILE(3) OVER (ORDER BY frequency)         AS f,
           NTILE(3) OVER (ORDER BY monetary)          AS m
    FROM base
)
SELECT c.name, s.recency_days, s.frequency, s.monetary,
       concat(s.r, s.f, s.m) AS rfm,
       CASE WHEN s.r + s.f + s.m >= 8 THEN '최우수'
            WHEN s.r = 1               THEN '이탈위험'
            ELSE '일반' END AS 세그먼트
FROM scored s JOIN customers c USING (customer_id)
ORDER BY s.r + s.f + s.m DESC, s.monetary DESC
LIMIT 8;

-- @ex 20-05 재구매율 - 2회 이상 구매한 고객 비율
WITH cnt AS (
    SELECT customer_id, count(DISTINCT order_id) AS n FROM v_sales GROUP BY customer_id
)
SELECT count(*) AS 구매고객,
       count(*) FILTER (WHERE n >= 2) AS 재구매고객,
       round(100.0 * count(*) FILTER (WHERE n >= 2) / count(*), 1) AS 재구매율
FROM cnt;

-- @ex 20-06 분기 코호트 - 첫 구매 분기별로 이후 분기에 다시 산 고객 수
WITH first AS (
    SELECT customer_id, date_trunc('quarter', min(order_date))::date AS cohort
    FROM v_sales GROUP BY customer_id
), activity AS (
    SELECT DISTINCT v.customer_id, f.cohort,
           (EXTRACT(YEAR FROM age(date_trunc('quarter', v.order_date), f.cohort)) * 4
            + EXTRACT(MONTH FROM age(date_trunc('quarter', v.order_date), f.cohort)) / 3)::int AS q
    FROM v_sales v JOIN first f USING (customer_id)
)
SELECT to_char(cohort, 'YYYY-"Q"Q') AS 코호트,
       count(*) FILTER (WHERE q = 0) AS q0,
       count(*) FILTER (WHERE q = 1) AS q1,
       count(*) FILTER (WHERE q = 2) AS q2,
       count(*) FILTER (WHERE q = 3) AS q3,
       count(*) FILTER (WHERE q = 4) AS q4
FROM activity
GROUP BY cohort
ORDER BY cohort;

-- @ex 20-07 장바구니 분석 - 함께 많이 팔린 상품 쌍
SELECT pa.name AS 상품1, pb.name AS 상품2, count(*) AS 함께주문
FROM order_items a
JOIN order_items b ON a.order_id = b.order_id AND a.product_id < b.product_id
JOIN products pa ON pa.product_id = a.product_id
JOIN products pb ON pb.product_id = b.product_id
GROUP BY pa.name, pb.name
HAVING count(*) >= 3
ORDER BY 함께주문 DESC, 상품1
LIMIT 5;

-- @ex 20-08 상품 성과표 - 매출 순위 + 평균 평점 + 분류 내 비중
WITH sales AS (
    SELECT product_id, category_id, sum(amount) AS sales, sum(quantity) AS qty
    FROM v_sales GROUP BY product_id, category_id
), rating AS (
    SELECT product_id, round(avg(rating), 2) AS avg_rating, count(*) AS reviews
    FROM reviews GROUP BY product_id
)
SELECT RANK() OVER (ORDER BY s.sales DESC) AS 순위,
       p.name, s.sales AS 매출, s.qty AS 수량,
       COALESCE(r.avg_rating, 0) AS 평점, COALESCE(r.reviews, 0) AS 리뷰수,
       round(100.0 * s.sales / sum(s.sales) OVER (PARTITION BY s.category_id), 1) AS 분류내비중
FROM sales s
JOIN products p USING (product_id)
LEFT JOIN rating r USING (product_id)
ORDER BY 순위
LIMIT 8;

-- @ex 20-09 영업사원 실적 - 담당 매출과 팀 내 순위
SELECT e.name, e.job_title,
       count(DISTINCT v.order_id) AS 담당주문,
       sum(v.amount) AS 담당매출,
       RANK() OVER (ORDER BY sum(v.amount) DESC) AS 순위
FROM v_sales v JOIN employees e ON e.emp_id = v.emp_id
GROUP BY e.emp_id, e.name, e.job_title
ORDER BY 순위;

-- @ex 20-10 리포트를 함수로 - 기간을 넣으면 분류별 매출을 돌려준다
CREATE OR REPLACE FUNCTION sales_report(p_from DATE, p_to DATE)
RETURNS TABLE (category TEXT, orders BIGINT, sales NUMERIC, share NUMERIC)
LANGUAGE sql STABLE
AS $$
    SELECT c.name::text, count(DISTINCT v.order_id), sum(v.amount),
           round(100.0 * sum(v.amount) / sum(sum(v.amount)) OVER (), 1)
    FROM v_sales v JOIN categories c USING (category_id)
    WHERE v.order_date >= p_from AND v.order_date < p_to
    GROUP BY c.name
    ORDER BY 3 DESC;
$$;
SELECT * FROM sales_report('2026-04-01', '2026-07-01');
