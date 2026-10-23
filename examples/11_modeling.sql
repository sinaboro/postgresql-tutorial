-- =====================================================================
-- 11장. 데이터 모델링과 정규화 - 좋은 테이블 설계
-- =====================================================================
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS model CASCADE;
RESET client_min_messages;
CREATE SCHEMA model;
SET search_path = model, public;

-- @ex 11-01 정규화 전 - 한 테이블에 모든 것을 넣은 "엑셀식" 주문표
CREATE TABLE flat_orders (
    order_no      INTEGER,
    order_date    DATE,
    customer_name VARCHAR(50),
    customer_tel  VARCHAR(20),
    products      TEXT,            -- '마우스, 키보드' 처럼 여러 값을 한 칸에 (1NF 위반)
    total_price   INTEGER
);
INSERT INTO flat_orders VALUES
    (1, '2026-10-01', '김철수', '010-1111-2222', '마우스, 키보드', 118000),
    (2, '2026-10-02', '김철수', '010-1111-2222', '모니터', 329000),
    (3, '2026-10-02', '이영희', '010-3333-4444', '마우스', 29000);
SELECT * FROM flat_orders;

-- @ex 11-02 이상 현상(Anomaly) - 김철수의 전화번호를 한 행만 바꾸면?
UPDATE flat_orders SET customer_tel = '010-9999-9999' WHERE order_no = 1;
SELECT order_no, customer_name, customer_tel FROM flat_orders WHERE customer_name = '김철수'
ORDER BY order_no;

-- @ex 11-03 '마우스'를 산 주문 찾기도 어렵다 (한 칸에 여러 값)
SELECT order_no, products FROM flat_orders WHERE products LIKE '%마우스%' ORDER BY order_no;

-- @ex 11-04 정규화 후 - 고객 / 상품 / 주문 / 주문상세로 분리 (3NF)
CREATE TABLE customer (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    tel         VARCHAR(20)
);
CREATE TABLE product (
    product_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    price       INTEGER     NOT NULL
);
CREATE TABLE "order" (                               -- order 는 예약어라 따옴표 필요 (권장 X)
    order_no    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customer,
    order_date  DATE    NOT NULL
);
CREATE TABLE order_line (
    order_no    INTEGER REFERENCES "order",
    product_id  INTEGER REFERENCES product,
    qty         INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (order_no, product_id)
);
INSERT INTO customer (name, tel) VALUES ('김철수', '010-1111-2222'), ('이영희', '010-3333-4444');
INSERT INTO product (name, price) VALUES ('마우스', 29000), ('키보드', 89000), ('모니터', 329000);
INSERT INTO "order" VALUES (1, 1, '2026-10-01'), (2, 1, '2026-10-02'), (3, 2, '2026-10-02');
INSERT INTO order_line VALUES (1, 1, 1), (1, 2, 1), (2, 3, 1), (3, 1, 1);

-- @ex 11-05 정규화된 테이블에서 원래 주문표 복원 (JOIN)
SELECT o.order_no, o.order_date, c.name, c.tel,
       string_agg(p.name, ', ' ORDER BY p.product_id) AS products,
       sum(p.price * ol.qty) AS total_price            -- 합계는 저장하지 않고 계산
FROM "order" o
JOIN customer c    ON c.customer_id = o.customer_id
JOIN order_line ol ON ol.order_no = o.order_no
JOIN product p     ON p.product_id = ol.product_id
GROUP BY o.order_no, o.order_date, c.name, c.tel
ORDER BY o.order_no;

-- @ex 11-06 이제 전화번호 변경은 한 곳만 고치면 된다
UPDATE customer SET tel = '010-9999-9999' WHERE name = '김철수';
SELECT o.order_no, c.name, c.tel
FROM "order" o JOIN customer c USING (customer_id)
ORDER BY o.order_no;

-- @ex 11-07 N:M 관계와 연결 테이블 - shop 의 주문(orders)↔상품(products)
SET search_path = public;
SELECT tc.table_name, kcu.column_name, ccu.table_name AS 참조테이블
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'order_items';

-- @ex 11-08 1:1 관계 - 고객 상세정보를 별도 테이블로 (PK 이자 FK)
CREATE TABLE model.customer_profile (
    customer_id INTEGER PRIMARY KEY REFERENCES model.customer,
    address     TEXT,
    marketing_agree BOOLEAN NOT NULL DEFAULT false
);
SELECT column_name, data_type, character_maximum_length AS max_len,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'customer_profile'
ORDER BY ordinal_position;
