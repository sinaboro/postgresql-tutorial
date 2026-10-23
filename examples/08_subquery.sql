-- =====================================================================
-- 08장. 서브쿼리 - 쿼리 안의 쿼리
-- =====================================================================

-- @ex 08-01 스칼라 서브쿼리 - 평균보다 비싼 상품
SELECT name, price
FROM products
WHERE price > (SELECT avg(price) FROM products)
ORDER BY price DESC;

-- @ex 08-02 SELECT 절의 스칼라 서브쿼리 - 전체 평균과 비교
SELECT name, price,
       (SELECT round(avg(price)) FROM products) AS 전체평균,
       price - (SELECT round(avg(price)) FROM products) AS 차이
FROM products
WHERE category_id = 4;

-- @ex 08-03 IN 서브쿼리 - 노트북 분류를 산 적 있는 고객
SELECT name FROM customers
WHERE customer_id IN (
    SELECT o.customer_id
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    WHERE oi.product_id IN (SELECT product_id FROM products WHERE category_id IN (4, 11))
)
ORDER BY name;

-- @ex 08-04 NOT IN 과 NULL 함정
-- 담당 직원이 한 번도 맡지 않은(=orders.emp_id 에 없는) 직원을 찾으려 했지만…
SELECT count(*) AS not_in_결과 FROM employees
WHERE emp_id NOT IN (SELECT emp_id FROM orders);             -- emp_id 에 NULL 이 있어 0건!
SELECT count(*) AS not_exists_결과 FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.emp_id = e.emp_id);

-- @ex 08-05 EXISTS - 리뷰를 남긴 적이 있는 고객
SELECT c.customer_id, c.name
FROM customers c
WHERE EXISTS (SELECT 1 FROM reviews r WHERE r.customer_id = c.customer_id)
ORDER BY c.customer_id
LIMIT 5;

-- @ex 08-06 상관 서브쿼리 - 자기 분류의 평균 가격보다 비싼 상품
SELECT p.name, p.category_id, p.price
FROM products p
WHERE p.price > (SELECT avg(p2.price) FROM products p2
                 WHERE p2.category_id = p.category_id)
ORDER BY p.category_id;

-- @ex 08-07 FROM 절 서브쿼리(인라인 뷰) - 고객 등급별 평균 구매액
SELECT grade, count(*) AS 고객수, round(avg(total)) AS 평균구매액
FROM (
    SELECT c.customer_id, c.grade, sum(oi.quantity * oi.unit_price) AS total
    FROM customers c
    JOIN orders o       ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.grade
) t
GROUP BY grade
ORDER BY 평균구매액 DESC;

-- @ex 08-08 ANY / ALL
SELECT name, price FROM products
WHERE price > ALL (SELECT price FROM products WHERE category_id = 5);  -- 모든 스마트폰보다 비쌈
SELECT name, price FROM products
WHERE price = ANY (ARRAY[29000, 45000, 12000]);                        -- IN 과 같은 효과

-- @ex 08-09 서브쿼리로 UPDATE / DELETE
UPDATE products
SET is_active = false
WHERE product_id NOT IN (SELECT DISTINCT product_id FROM order_items)
RETURNING product_id, name;

-- @ex 08-10 스칼라 서브쿼리는 한 행만 반환해야 한다 [error]
SELECT name FROM products WHERE price = (SELECT price FROM products WHERE category_id = 5);

-- @ex 08-11 [심화] LATERAL - 각 분류별 가장 비싼 상품 2개
SELECT c.name AS 분류, t.name AS 상품, t.price
FROM categories c
CROSS JOIN LATERAL (
    SELECT p.name, p.price FROM products p
    WHERE p.category_id = c.category_id
    ORDER BY p.price DESC
    LIMIT 2
) t
WHERE c.category_id IN (5, 6, 7);
