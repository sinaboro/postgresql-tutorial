-- =====================================================================
-- 실습 문제 정답 : 05장(함수) ~ 07장(JOIN)
-- =====================================================================

-- @ex 05-Q1 고객 이름과 이메일 도메인(@ 뒤)을 출력하고, 이메일 아이디는 앞 2글자만 보이고 나머지는 * 로 가리세요 (고객 3명)
SELECT name,
       split_part(email, '@', 2) AS 도메인,
       left(email, 2) || repeat('*', length(split_part(email, '@', 1)) - 2) AS 가린아이디
FROM customers ORDER BY customer_id LIMIT 3;

-- @ex 05-Q2 상품 가격을 '1,290,000원' 형식의 문자열로 출력하세요 (노트북 분류 4)
SELECT name, to_char(price, 'FM9,999,999') || '원' AS 가격
FROM products WHERE category_id = 4;

-- @ex 05-Q3 직원의 근속 연수(2026-10-23 기준, 만)를 구하고 근속 10년 이상이면 '장기근속', 아니면 '일반'으로 표시하세요
SELECT name, hire_date,
       EXTRACT(YEAR FROM age(date '2026-10-23', hire_date)) AS 근속연수,
       CASE WHEN age(date '2026-10-23', hire_date) >= interval '10 years'
            THEN '장기근속' ELSE '일반' END AS 구분
FROM employees ORDER BY hire_date LIMIT 5;

-- @ex 05-Q4 주문을 요일별(월~일)로 집계하세요. 요일은 to_char 로 이름을 출력하고 ISO 요일 번호(1=월) 순으로 정렬
SELECT EXTRACT(ISODOW FROM order_date) AS 번호,
       to_char(order_date, 'FMDay') AS 요일,
       count(*) AS 주문수
FROM orders
GROUP BY 1, 2 ORDER BY 1;

-- @ex 05-Q5 전화번호가 없으면 '미등록', 생일이 없으면 '알수없음'을 표시하세요 (해당 고객만)
SELECT name,
       COALESCE(phone, '미등록') AS phone,
       COALESCE(birth_date::text, '알수없음') AS birth
FROM customers
WHERE phone IS NULL OR birth_date IS NULL
ORDER BY customer_id;

-- @ex 06-Q1 고객 등급(grade)별 고객 수와 평균 나이(2026-10-23 기준, 소수 1자리)를 구하세요
SELECT grade, count(*) AS 고객수,
       round(avg(EXTRACT(YEAR FROM age(date '2026-10-23', birth_date))), 1) AS 평균나이
FROM customers GROUP BY grade ORDER BY 고객수 DESC;

-- @ex 06-Q2 배송 도시(ship_city)별 주문 수가 15건 이상인 도시만, 주문 수 내림차순으로 조회하세요
SELECT ship_city, count(*) AS 주문수
FROM orders GROUP BY ship_city
HAVING count(*) >= 15
ORDER BY 주문수 DESC;

-- @ex 06-Q3 2025년 분기별 주문 수와 취소 건수, 취소율(%)을 한 번에 구하세요
SELECT EXTRACT(QUARTER FROM order_date) AS 분기,
       count(*) AS 주문수,
       count(*) FILTER (WHERE status = 'CANCELLED') AS 취소,
       round(100.0 * count(*) FILTER (WHERE status = 'CANCELLED') / count(*), 1) AS 취소율
FROM orders
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'
GROUP BY 1 ORDER BY 1;

-- @ex 06-Q4 리뷰 평점별 개수와 평점 5점 리뷰가 1개 이상인 상품 수를 구하세요
SELECT rating, count(*) AS 리뷰수 FROM reviews GROUP BY rating ORDER BY rating DESC;
SELECT count(DISTINCT product_id) AS 만점상품수 FROM reviews WHERE rating = 5;

-- @ex 07-Q1 상품명, 분류명, 상위 분류명을 함께 출력하세요 (상위 분류가 없으면 NULL, 상품 1~5)
SELECT p.name AS 상품, c.name AS 분류, parent.name AS 상위분류
FROM products p
JOIN categories c           ON c.category_id = p.category_id
LEFT JOIN categories parent ON parent.category_id = c.parent_id
WHERE p.product_id <= 5 ORDER BY p.product_id;

-- @ex 07-Q2 한 번도 팔리지 않은 상품을 LEFT JOIN 으로 찾으세요
SELECT p.product_id, p.name
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_id IS NULL;

-- @ex 07-Q3 부서별 직원 수와 평균 연봉을 구하되, 직원이 없는 부서도 0명으로 나오게 하세요 (부서 없는 직원 제외)
SELECT d.name AS 부서, count(e.emp_id) AS 직원수, round(avg(e.salary)) AS 평균연봉
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.name ORDER BY d.dept_id;

-- @ex 07-Q4 자기 상사보다 입사일이 빠른 직원이 있는지 SELF JOIN 으로 확인하세요
SELECT e.name AS 직원, e.hire_date, m.name AS 상사, m.hire_date AS 상사입사일
FROM employees e JOIN employees m ON e.manager_id = m.emp_id
WHERE e.hire_date < m.hire_date;

-- @ex 07-Q5 도시별 매출 TOP 3 (주문의 배송 도시 기준, 취소 제외)
SELECT o.ship_city, sum(oi.quantity * oi.unit_price) AS 매출
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY o.ship_city ORDER BY 매출 DESC LIMIT 3;
