-- =====================================================================
-- 실습 문제 정답 : 08장(서브쿼리) ~ 10장(윈도우 함수)
-- =====================================================================

-- @ex 08-Q1 가장 비싼 상품과 같은 분류에 속한 상품을 모두 조회하세요
SELECT name, price FROM products
WHERE category_id = (SELECT category_id FROM products ORDER BY price DESC LIMIT 1);

-- @ex 08-Q2 평균 연봉보다 많이 받는 직원의 이름, 연봉, 평균과의 차이를 구하세요
SELECT name, salary, salary - (SELECT round(avg(salary)) FROM employees) AS 평균대비
FROM employees
WHERE salary > (SELECT avg(salary) FROM employees)
ORDER BY salary DESC;

-- @ex 08-Q3 리뷰를 한 번도 남기지 않은 '구매 고객'을 NOT EXISTS 로 찾으세요
SELECT c.customer_id, c.name FROM customers c
WHERE EXISTS     (SELECT 1 FROM orders o  WHERE o.customer_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.customer_id = c.customer_id)
ORDER BY c.customer_id;

-- @ex 08-Q4 각 고객의 마지막 주문일을 상관 서브쿼리로 구하세요 (고객 1~5)
SELECT c.name,
       (SELECT max(o.order_date)::date FROM orders o WHERE o.customer_id = c.customer_id) AS 마지막주문
FROM customers c WHERE c.customer_id <= 5 ORDER BY c.customer_id;

-- @ex 09-Q1 고객 도시와 직원 근무지(부서 location)를 합쳐 중복 없는 도시 목록을 만드세요
SELECT city FROM customers
UNION
SELECT location FROM departments
ORDER BY 1;

-- @ex 09-Q2 CTE 로 상품별 매출을 구한 뒤, 전체 매출의 10% 이상을 차지하는 상품만 출력하세요
WITH s AS (
    SELECT product_id, sum(quantity * unit_price) AS sales FROM order_items GROUP BY product_id
)
SELECT p.name, s.sales, round(100.0 * s.sales / (SELECT sum(sales) FROM s), 1) AS 비중
FROM s JOIN products p USING (product_id)
WHERE s.sales >= 0.1 * (SELECT sum(sales) FROM s)
ORDER BY s.sales DESC;

-- @ex 09-Q3 재귀 CTE 로 '오세훈' 사원부터 대표까지의 결재 라인을 출력하세요
WITH RECURSIVE chain AS (
    SELECT emp_id, name, job_title, manager_id, 1 AS lvl FROM employees WHERE name = '오세훈'
    UNION ALL
    SELECT e.emp_id, e.name, e.job_title, e.manager_id, c.lvl + 1
    FROM employees e JOIN chain c ON e.emp_id = c.manager_id
)
SELECT lvl, name, job_title FROM chain ORDER BY lvl;

-- @ex 09-Q4 '전자제품'(1) 아래의 모든 하위 분류에 속한 상품 수를 재귀 CTE 로 구하세요
WITH RECURSIVE sub AS (
    SELECT category_id FROM categories WHERE category_id = 1
    UNION ALL
    SELECT c.category_id FROM categories c JOIN sub s ON c.parent_id = s.category_id
)
SELECT count(*) AS 전자제품_상품수 FROM products WHERE category_id IN (SELECT category_id FROM sub);

-- @ex 10-Q1 고객별 주문에 순번을 매기고 각 고객의 첫 주문만 출력하세요 (고객 1~5)
SELECT customer_id, order_id, order_date
FROM (SELECT o.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
      FROM orders o) t
WHERE rn = 1 AND customer_id <= 5
ORDER BY customer_id;

-- @ex 10-Q2 분류별로 상품을 가격 순위로 매기고 분류 내 최고가와의 차이를 구하세요 (분류 4, 5, 6)
SELECT category_id, name, price,
       DENSE_RANK() OVER w AS 순위,
       max(price) OVER (PARTITION BY category_id) - price AS 최고가와차이
FROM products
WHERE category_id IN (4, 5, 6)
WINDOW w AS (PARTITION BY category_id ORDER BY price DESC)
ORDER BY category_id, 순위;

-- @ex 10-Q3 2025년 월별 주문 수와 3개월 이동 합계를 구하세요
WITH m AS (
    SELECT date_trunc('month', order_date)::date AS 월, count(*) AS 주문수
    FROM orders WHERE order_date < '2026-01-01' GROUP BY 1
)
SELECT 월, 주문수,
       sum(주문수) OVER (ORDER BY 월 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS 이동합계3
FROM m ORDER BY 월;

-- @ex 10-Q4 직원을 연봉 기준으로 상위/중위/하위 3그룹(NTILE)으로 나누고 그룹별 인원과 평균을 구하세요
SELECT 그룹, count(*) AS 인원, round(avg(salary)) AS 평균연봉
FROM (SELECT salary, NTILE(3) OVER (ORDER BY salary DESC) AS 그룹 FROM employees) t
GROUP BY 그룹 ORDER BY 그룹;

-- @ex 10-Q5 고객 1번의 주문별 금액과 누적 구매액을 구하세요 (취소 제외)
SELECT o.order_id, o.order_date::date,
       sum(oi.quantity * oi.unit_price) AS 금액,
       sum(sum(oi.quantity * oi.unit_price)) OVER (ORDER BY o.order_date) AS 누적
FROM orders o JOIN order_items oi USING (order_id)
WHERE o.customer_id = 1 AND o.status <> 'CANCELLED'
GROUP BY o.order_id, o.order_date
ORDER BY o.order_date;
