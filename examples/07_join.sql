-- =====================================================================
-- 07장. JOIN - 여러 테이블 연결하기
-- =====================================================================

-- @ex 07-01 INNER JOIN - 직원과 부서 이름
SELECT e.emp_id, e.name, d.name AS 부서명
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id
LIMIT 6;

-- @ex 07-02 INNER JOIN 은 짝이 없는 행을 버린다 (부서 없는 인턴이 빠짐)
SELECT count(*) AS 전체직원 FROM employees;
SELECT count(*) AS 조인결과 FROM employees e JOIN departments d ON e.dept_id = d.dept_id;

-- @ex 07-03 LEFT JOIN - 왼쪽 테이블은 모두 남긴다
SELECT e.name, e.job_title, d.name AS 부서명
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id >= 13;

-- @ex 07-04 LEFT JOIN + IS NULL - 주문한 적 없는 고객 찾기
SELECT c.customer_id, c.name, c.joined_at::date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- @ex 07-05 3개 이상 테이블 조인 - 주문 상세 내역
SELECT o.order_id, c.name AS 고객, p.name AS 상품, oi.quantity AS 수량,
       oi.quantity * oi.unit_price AS 금액
FROM orders o
JOIN customers   c  ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products    p  ON oi.product_id = p.product_id
WHERE o.order_id BETWEEN 1 AND 3
ORDER BY o.order_id, p.name;

-- @ex 07-06 JOIN + GROUP BY - 고객별 총 구매액 TOP 5
SELECT c.name, c.grade, count(DISTINCT o.order_id) AS 주문수,
       sum(oi.quantity * oi.unit_price) AS 총구매액
FROM customers c
JOIN orders o       ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY c.customer_id, c.name, c.grade
ORDER BY 총구매액 DESC
LIMIT 5;

-- @ex 07-07 카테고리별 매출 (상품 → 분류 조인)
SELECT cat.name AS 분류, sum(oi.quantity * oi.unit_price) AS 매출
FROM order_items oi
JOIN products p     ON oi.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
GROUP BY cat.name
ORDER BY 매출 DESC;

-- @ex 07-08 LEFT JOIN 에서 조건 위치 주의 - ON 과 WHERE 의 차이
-- (의도) 모든 상품과, 리뷰가 있다면 그중 5점짜리 개수
SELECT p.product_id, count(r.review_id) AS 만점리뷰
FROM products p
LEFT JOIN reviews r ON p.product_id = r.product_id
WHERE r.rating = 5                        -- WHERE 에 두면 LEFT JOIN 이 INNER 처럼 됨
GROUP BY p.product_id ORDER BY p.product_id LIMIT 5;
SELECT p.product_id, count(r.review_id) AS 만점리뷰
FROM products p
LEFT JOIN reviews r ON p.product_id = r.product_id AND r.rating = 5   -- ON 에 둬야 함
GROUP BY p.product_id ORDER BY p.product_id LIMIT 5;

-- @ex 07-09 RIGHT JOIN 과 FULL OUTER JOIN
SELECT d.name AS 부서, e.name AS 직원
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id AND e.salary >= 9000;
SELECT d.name AS 부서, e.name AS 직원
FROM (SELECT * FROM employees WHERE salary < 3000 OR dept_id = 5) e
FULL OUTER JOIN (SELECT * FROM departments WHERE dept_id IN (4, 5)) d
     ON e.dept_id = d.dept_id;

-- @ex 07-10 SELF JOIN - 직원과 상사 이름
SELECT e.name AS 직원, e.job_title, m.name AS 상사
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id
ORDER BY e.emp_id
LIMIT 8;

-- @ex 07-11 CROSS JOIN - 모든 조합 만들기
SELECT s.size, c.color
FROM (VALUES ('S'), ('M'), ('L')) AS s(size)
CROSS JOIN (VALUES ('흰색'), ('검정')) AS c(color);

-- @ex 07-12 USING 과 NATURAL JOIN (컬럼 이름이 같을 때)
SELECT order_id, product_id, quantity, customer_id
FROM order_items JOIN orders USING (order_id)
LIMIT 3;
-- NATURAL JOIN 은 이름이 같은 모든 컬럼으로 조인한다 → 의도치 않은 결과 위험!
SELECT count(*) AS natural_join_결과
FROM employees NATURAL JOIN departments;        -- dept_id 와 name 둘 다로 조인됨

-- @ex 07-13 비등가 조인 - 가격 구간표와 조인
SELECT p.name, p.price, g.label
FROM products p
JOIN (VALUES (0, 50000, '저가'), (50000, 500000, '중가'), (500000, 99999999, '고가'))
     AS g(lo, hi, label)
  ON p.price >= g.lo AND p.price < g.hi
WHERE p.product_id IN (3, 8, 15);
