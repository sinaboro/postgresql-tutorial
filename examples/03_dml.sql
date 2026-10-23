-- =====================================================================
-- 03장. 데이터 다루기 - INSERT / UPDATE / DELETE (DML)
--   이 장의 실습은 shop 데이터를 바꿉니다. 끝나면 setup 스크립트로 다시 초기화하세요.
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS todo, inventory, inventory_in CASCADE;
RESET client_min_messages;
CREATE TABLE todo (
    todo_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task     VARCHAR(100) NOT NULL,
    priority INTEGER NOT NULL DEFAULT 3,
    done     BOOLEAN NOT NULL DEFAULT false
);

-- @ex 03-01 INSERT - 한 행 넣기 (컬럼 목록을 쓰는 습관!)
INSERT INTO todo (task, priority) VALUES ('PostgreSQL 설치하기', 1);
INSERT INTO todo (task) VALUES ('psql 접속해 보기');          -- priority, done 은 DEFAULT
SELECT * FROM todo;

-- @ex 03-02 INSERT - 여러 행을 한 번에
INSERT INTO todo (task, priority) VALUES
    ('SELECT 연습', 2),
    ('JOIN 이해하기', 2),
    ('인덱스 공부', 4);
SELECT * FROM todo ORDER BY todo_id;

-- @ex 03-03 RETURNING - 방금 넣은 행(자동 생성된 ID)을 바로 돌려받기
INSERT INTO todo (task, priority) VALUES ('트랜잭션 공부', 3)
RETURNING todo_id, task;

-- @ex 03-04 INSERT ... SELECT - 조회 결과를 그대로 넣기
INSERT INTO todo (task, priority)
SELECT name || ' 부서 미팅', 5 FROM departments WHERE location = '서울';
SELECT * FROM todo WHERE priority = 5;

-- @ex 03-05 UPDATE - 조건에 맞는 행 수정
UPDATE todo SET done = true WHERE todo_id IN (1, 2);
UPDATE todo SET priority = priority - 1, task = task || ' (중요)'
WHERE priority >= 4
RETURNING todo_id, task, priority;

-- @ex 03-06 DELETE - 조건에 맞는 행 삭제
DELETE FROM todo WHERE task LIKE '%부서 미팅%';
DELETE FROM todo WHERE done RETURNING *;
SELECT * FROM todo ORDER BY todo_id;

-- @ex 03-07 [주의] WHERE 없는 UPDATE/DELETE 는 모든 행에 적용된다
BEGIN;                                     -- 안전하게 트랜잭션 안에서 실험
UPDATE todo SET priority = 0;              -- 모든 행이 바뀐다!
SELECT todo_id, priority FROM todo ORDER BY todo_id;
ROLLBACK;                                  -- 없던 일로
SELECT todo_id, priority FROM todo ORDER BY todo_id;

-- @ex 03-08 실제 shop 데이터 수정 - 재고 입고와 가격 인상
UPDATE products SET stock = stock + 30 WHERE product_id = 9 RETURNING name, stock;
UPDATE products SET price = price * 1.1
WHERE category_id = 9
RETURNING product_id, name, price;

-- @ex 03-09 다른 테이블을 참고해서 UPDATE (UPDATE ... FROM)
-- 주문이 10건 이상인 BRONZE/SILVER 고객을 GOLD 로 승급
UPDATE customers c
SET grade = 'GOLD'
FROM (SELECT customer_id, count(*) AS cnt
      FROM orders
      GROUP BY customer_id) o
WHERE c.customer_id = o.customer_id
  AND o.cnt >= 10
  AND c.grade IN ('BRONZE', 'SILVER')
RETURNING c.customer_id, c.name, c.grade, o.cnt;

-- @ex 03-10 참조되고 있는 행은 지울 수 없다 [error]
DELETE FROM customers WHERE customer_id = 1;     -- orders 가 참조 중

-- @ex 03-11 UPSERT - INSERT ... ON CONFLICT
CREATE TABLE inventory (
    sku   VARCHAR(20) PRIMARY KEY,
    qty   INTEGER NOT NULL
);
INSERT INTO inventory VALUES ('A-100', 10), ('B-200', 5);
-- 이미 있으면 수량을 더하고, 없으면 새로 넣는다
INSERT INTO inventory (sku, qty) VALUES ('A-100', 3), ('C-300', 7)
ON CONFLICT (sku) DO UPDATE SET qty = inventory.qty + EXCLUDED.qty;
-- 이미 있으면 아무것도 하지 않는다
INSERT INTO inventory (sku, qty) VALUES ('B-200', 999)
ON CONFLICT (sku) DO NOTHING;
SELECT * FROM inventory ORDER BY sku;

-- @ex 03-12 MERGE (PostgreSQL 15+) - 조건에 따라 INSERT/UPDATE/DELETE 를 한 문장으로
CREATE TABLE inventory_in (sku VARCHAR(20), qty INTEGER);
INSERT INTO inventory_in VALUES ('A-100', -13), ('B-200', 5), ('D-400', 2);
MERGE INTO inventory t
USING inventory_in s ON t.sku = s.sku
WHEN MATCHED AND t.qty + s.qty <= 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET qty = t.qty + s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
SELECT * FROM inventory ORDER BY sku;
