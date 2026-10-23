-- =====================================================================
-- 06장. 집계와 그룹화 - GROUP BY, HAVING, 고급 그룹핑
-- =====================================================================

-- @ex 06-01 집계 함수 기본
SELECT count(*)      AS 상품수,
       sum(stock)    AS 총재고,
       avg(price)    AS 평균가,
       round(avg(price)) AS 평균가_반올림,
       min(price)    AS 최저가,
       max(price)    AS 최고가
FROM products;

-- @ex 06-02 count(*) vs count(컬럼) vs count(DISTINCT 컬럼)
SELECT count(*)              AS 전체행,
       count(phone)          AS 전화있음,      -- NULL 은 세지 않음
       count(DISTINCT city)  AS 도시수
FROM customers;

-- @ex 06-03 GROUP BY - 그룹별 집계
SELECT city, count(*) AS 고객수
FROM customers
GROUP BY city
ORDER BY 고객수 DESC, city;

-- @ex 06-04 여러 컬럼으로 그룹화
SELECT status, EXTRACT(YEAR FROM order_date) AS 연도, count(*) AS 주문수
FROM orders
GROUP BY status, EXTRACT(YEAR FROM order_date)
ORDER BY 연도, status;

-- @ex 06-05 GROUP BY 규칙 위반 [error]
-- SELECT 에는 GROUP BY 컬럼 또는 집계 함수만 올 수 있다
SELECT city, name, count(*) FROM customers GROUP BY city;

-- @ex 06-06 매출 계산 - 주문 상세(order_items)로 상품별 판매량/매출
SELECT product_id,
       sum(quantity)              AS 판매수량,
       sum(quantity * unit_price) AS 매출
FROM order_items
GROUP BY product_id
ORDER BY 매출 DESC
LIMIT 5;

-- @ex 06-07 HAVING - 그룹에 조건 걸기 (WHERE 는 그룹 전, HAVING 은 그룹 후)
SELECT customer_id, count(*) AS 주문수
FROM orders
WHERE status <> 'CANCELLED'
GROUP BY customer_id
HAVING count(*) >= 10
ORDER BY 주문수 DESC;

-- @ex 06-08 월별 매출 추이 (date_trunc 활용)
SELECT to_char(date_trunc('month', o.order_date), 'YYYY-MM') AS 월,
       count(DISTINCT o.order_id)          AS 주문수,
       sum(oi.quantity * oi.unit_price)    AS 매출
FROM orders o, order_items oi
WHERE o.order_id = oi.order_id
  AND o.status <> 'CANCELLED'
  AND o.order_date >= '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- @ex 06-09 조건부 집계 - FILTER 절과 CASE
SELECT count(*)                                         AS 전체,
       count(*) FILTER (WHERE status = 'DELIVERED')     AS 배송완료,
       count(*) FILTER (WHERE status = 'CANCELLED')     AS 취소,
       sum(CASE WHEN emp_id IS NULL THEN 1 ELSE 0 END)  AS 온라인주문
FROM orders;

-- @ex 06-10 문자열/배열 집계 - string_agg, array_agg
SELECT city,
       string_agg(name, ', ' ORDER BY name) AS 고객명단,
       array_agg(customer_id ORDER BY customer_id) AS id목록
FROM customers
GROUP BY city
ORDER BY city
LIMIT 4;

-- @ex 06-11 [심화] ROLLUP - 소계와 총계
SELECT COALESCE(location, '[전체]') AS 근무지,
       COALESCE(job_title, '[소계]') AS 직무,
       count(*) AS 인원, sum(salary) AS 연봉합
FROM employees e JOIN departments d ON e.dept_id = d.dept_id
WHERE location <> '서울'
GROUP BY ROLLUP (location, job_title)
ORDER BY location NULLS LAST, job_title NULLS LAST;

-- @ex 06-12 [심화] GROUPING SETS - 여러 기준의 집계를 한 번에
SELECT city, grade, count(*)
FROM customers
WHERE city IN ('서울', '부산')
GROUP BY GROUPING SETS ((city), (grade), ())
ORDER BY city NULLS LAST, grade NULLS LAST;

-- @ex 06-13 [심화] 통계 함수
SELECT round(stddev(salary), 1)                         AS 표준편차,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS 중앙값,
       mode() WITHIN GROUP (ORDER BY dept_id)            AS 최빈부서
FROM employees;
