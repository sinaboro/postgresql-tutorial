-- =====================================================================
-- 15장. 함수, 프로시저, 트리거 - PL/pgSQL
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS product_price_log;
RESET client_min_messages;

-- @ex 15-01 SQL 함수 - 가장 간단한 사용자 정의 함수
CREATE OR REPLACE FUNCTION vat(price NUMERIC)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$
    SELECT round(price * 1.1);
$$;
SELECT name, price, vat(price) AS 부가세포함 FROM products WHERE product_id <= 3;

-- @ex 15-02 PL/pgSQL 함수 - 변수, IF, RETURN
CREATE OR REPLACE FUNCTION customer_level(p_customer_id INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(sum(oi.quantity * oi.unit_price), 0)
      INTO v_total
    FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = p_customer_id AND o.status <> 'CANCELLED';

    IF v_total >= 10000000 THEN
        RETURN 'VIP';
    ELSIF v_total >= 5000000 THEN
        RETURN 'GOLD';
    ELSIF v_total > 0 THEN
        RETURN 'SILVER';
    ELSE
        RETURN 'NEW';
    END IF;
END;
$$;
SELECT customer_id, name, grade AS 현재등급, customer_level(customer_id) AS 계산등급
FROM customers WHERE customer_id IN (1, 4, 10, 19);

-- @ex 15-03 테이블을 반환하는 함수 (RETURNS TABLE)
CREATE OR REPLACE FUNCTION top_products(p_limit INTEGER DEFAULT 3)
RETURNS TABLE (product_name VARCHAR, total_qty BIGINT)
LANGUAGE sql STABLE
AS $$
    SELECT p.name, sum(oi.quantity)
    FROM order_items oi JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.name
    ORDER BY 2 DESC, 1
    LIMIT p_limit;
$$;
SELECT * FROM top_products();
SELECT * FROM top_products(p_limit => 5);

-- @ex 15-04 반복문(FOR … LOOP)과 RAISE NOTICE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT name, stock FROM products WHERE stock < 10 ORDER BY stock LOOP
        RAISE NOTICE '재고 부족: % (현재 %개)', r.name, r.stock;
    END LOOP;
END;
$$;

-- @ex 15-05 예외 처리 - EXCEPTION 블록
CREATE OR REPLACE FUNCTION safe_divide(a NUMERIC, b NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN a / b;
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE '0 으로 나눌 수 없어 NULL 을 반환합니다';
        RETURN NULL;
END;
$$;
SELECT safe_divide(10, 4) AS 정상, safe_divide(10, 0) AS 영나누기;

-- @ex 15-06 RAISE EXCEPTION - 업무 규칙 위반 시 오류 발생 [error]
CREATE OR REPLACE FUNCTION place_order(p_customer INTEGER, p_product INTEGER, p_qty INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
    v_price NUMERIC;
    v_order INTEGER;
BEGIN
    SELECT stock, price INTO v_stock, v_price
    FROM products WHERE product_id = p_product
    FOR UPDATE;                                   -- 동시 주문 대비 잠금

    IF NOT FOUND THEN
        RAISE EXCEPTION '상품 %이(가) 없습니다', p_product;
    END IF;
    IF v_stock < p_qty THEN
        RAISE EXCEPTION '재고 부족: 요청 %개, 재고 %개', p_qty, v_stock
              USING HINT = '수량을 줄여 다시 주문하세요';
    END IF;

    INSERT INTO orders (customer_id, order_date, status, ship_city)
    SELECT p_customer, now(), 'PAID', city FROM customers WHERE customer_id = p_customer
    RETURNING order_id INTO v_order;

    INSERT INTO order_items VALUES (v_order, p_product, p_qty, v_price);
    UPDATE products SET stock = stock - p_qty WHERE product_id = p_product;
    RETURN v_order;
END;
$$;
SELECT place_order(1, 3, 100);       -- 재고 6개뿐

-- @ex 15-07 정상 주문 - 함수 하나가 하나의 트랜잭션으로 실행된다
SELECT place_order(1, 3, 2) AS 새주문번호;
SELECT stock FROM products WHERE product_id = 3;

-- @ex 15-08 프로시저(PROCEDURE) - CALL 로 실행, 내부에서 COMMIT 가능
CREATE OR REPLACE PROCEDURE cancel_old_pending(p_days INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cnt INTEGER;
BEGIN
    UPDATE orders SET status = 'CANCELLED'
    WHERE status = 'PENDING' AND order_date < now() - make_interval(days => p_days);
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '% 건 자동 취소', v_cnt;
    COMMIT;
END;
$$;
INSERT INTO orders (customer_id, order_date, status, ship_city)
VALUES (2, now() - interval '10 days', 'PENDING', '부산');
CALL cancel_old_pending(7);

-- @ex 15-09 트리거 1 - 가격 변경 이력 자동 기록 (AFTER UPDATE)
CREATE TABLE product_price_log (
    log_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INTEGER,
    old_price  NUMERIC,
    new_price  NUMERIC,
    changed_by TEXT DEFAULT current_user,
    changed_at TIMESTAMP DEFAULT now()
);
CREATE OR REPLACE FUNCTION trg_log_price()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO product_price_log (product_id, old_price, new_price)
    VALUES (OLD.product_id, OLD.price, NEW.price);
    RETURN NEW;
END;
$$;
CREATE TRIGGER products_price_audit
AFTER UPDATE OF price ON products
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION trg_log_price();

UPDATE products SET price = price - 10000 WHERE product_id IN (6, 7);
UPDATE products SET stock = stock + 1 WHERE product_id = 6;      -- 가격 변경 아님 → 기록 X
SELECT product_id, old_price, new_price, changed_by FROM product_price_log;

-- @ex 15-10 트리거 2 - 데이터 검증/보정 (BEFORE INSERT OR UPDATE)
CREATE OR REPLACE FUNCTION trg_normalize_customer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.email := lower(trim(NEW.email));                -- 이메일 정규화
    NEW.phone := regexp_replace(NEW.phone, '[^0-9]', '', 'g');
    IF length(NEW.phone) = 11 THEN                       -- 01012345678 → 010-1234-5678
        NEW.phone := substr(NEW.phone, 1, 3) || '-' || substr(NEW.phone, 4, 4)
                     || '-' || substr(NEW.phone, 8);
    END IF;
    RETURN NEW;                                          -- 수정된 NEW 가 저장된다
END;
$$;
CREATE TRIGGER customers_normalize
BEFORE INSERT OR UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION trg_normalize_customer();

INSERT INTO customers (name, email, phone, city)
VALUES ('트리거테스트', '  Test.User@Example.COM ', '010 5555 1234', '서울')
RETURNING customer_id, email, phone;

-- @ex 15-11 함수/트리거 목록 확인
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_type, routine_name;
SELECT tgname, tgrelid::regclass AS 테이블
FROM pg_trigger WHERE NOT tgisinternal ORDER BY tgname;
