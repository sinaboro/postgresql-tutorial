-- =====================================================================
-- 실습 문제 정답 : 02장(DDL) ~ 04장(SELECT 기초)
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS books, loans, book_members;
RESET client_min_messages;

-- @ex 02-Q1 도서(books) 테이블 만들기: book_id(자동증가 PK), title(필수, 200자), author(100자), price(0 이상 정수), published(날짜), in_stock(기본 true)
CREATE TABLE books (
    book_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title     VARCHAR(200) NOT NULL,
    author    VARCHAR(100),
    price     INTEGER CHECK (price >= 0),
    published DATE,
    in_stock  BOOLEAN NOT NULL DEFAULT true
);
\d books

-- @ex 02-Q2 회원(book_members)과 대출(loans) 테이블을 만들고 loans 가 books, book_members 를 참조하도록 외래 키를 거세요 (대출일 기본값 오늘)
CREATE TABLE book_members (
    member_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      VARCHAR(50) NOT NULL
);
CREATE TABLE loans (
    loan_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id   INTEGER NOT NULL REFERENCES books (book_id),
    member_id INTEGER NOT NULL REFERENCES book_members (member_id),
    loaned_on DATE    NOT NULL DEFAULT current_date,
    returned_on DATE
);
SELECT conname, contype FROM pg_constraint
WHERE conrelid = 'loans'::regclass AND contype IN ('p', 'f') ORDER BY conname;

-- @ex 02-Q3 books 에 isbn 컬럼(13자, 중복 불가)을 추가하고, price 컬럼 이름을 list_price 로 바꾸세요
ALTER TABLE books ADD COLUMN isbn CHAR(13) UNIQUE;
ALTER TABLE books RENAME COLUMN price TO list_price;
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'books' ORDER BY ordinal_position;

-- @ex 03-Q1 books 에 책 3권을 한 번에 넣고 생성된 book_id 와 title 을 RETURNING 으로 확인하세요
INSERT INTO books (title, author, list_price, published) VALUES
    ('혼자 공부하는 SQL', '우재남', 22000, '2021-06-01'),
    ('PostgreSQL 실전', '김디비', 35000, '2025-03-15'),
    ('데이터 모델링 입문', '이설계', 28000, '2023-09-20')
RETURNING book_id, title;

-- @ex 03-Q2 2023년 이전에 출간된 책의 가격을 10% 인하하고 바뀐 행을 확인하세요
UPDATE books SET list_price = list_price * 0.9
WHERE published < '2023-01-01'
RETURNING title, list_price;

-- @ex 03-Q3 shop: 재고가 0 인 상품의 is_active 를 false 로 바꾸고, 바뀐 상품명을 출력하세요
UPDATE products SET is_active = false
WHERE stock = 0
RETURNING name;

-- @ex 03-Q4 shop: inventory_log(sku PK, qty) 에 ('P-1', 5) 를 UPSERT 로 두 번 실행해 qty 가 10 이 되게 하세요
CREATE TABLE inventory_log (sku TEXT PRIMARY KEY, qty INT NOT NULL);
INSERT INTO inventory_log VALUES ('P-1', 5)
ON CONFLICT (sku) DO UPDATE SET qty = inventory_log.qty + EXCLUDED.qty;
INSERT INTO inventory_log VALUES ('P-1', 5)
ON CONFLICT (sku) DO UPDATE SET qty = inventory_log.qty + EXCLUDED.qty;
SELECT * FROM inventory_log;

-- @ex 04-Q1 가격이 50,000원 이상 300,000원 이하인 상품의 이름과 가격을 가격 내림차순으로 조회하세요
SELECT name, price FROM products
WHERE price BETWEEN 50000 AND 300000
ORDER BY price DESC;

-- @ex 04-Q2 이메일이 'j' 로 시작하는 고객의 이름, 이메일을 조회하세요
SELECT name, email FROM customers WHERE email LIKE 'j%' ORDER BY name;

-- @ex 04-Q3 서울·인천에 사는 1990년 이후 출생 고객을 생년월일 순으로 조회하세요
SELECT name, city, birth_date FROM customers
WHERE city IN ('서울', '인천')
  AND birth_date >= '1990-01-01'
ORDER BY birth_date;

-- @ex 04-Q4 주문 상태(status)의 종류를 중복 없이 조회하세요
SELECT DISTINCT status FROM orders ORDER BY status;

-- @ex 04-Q5 가장 최근에 가입한 고객 3명의 이름과 가입일시를 조회하세요
SELECT name, joined_at FROM customers ORDER BY joined_at DESC LIMIT 3;

-- @ex 04-Q6 2025년 12월에 들어온 주문 중 담당 직원이 없는(온라인) 주문을 조회하세요
SELECT order_id, customer_id, order_date FROM orders
WHERE order_date >= '2025-12-01' AND order_date < '2026-01-01'
  AND emp_id IS NULL
ORDER BY order_date;
