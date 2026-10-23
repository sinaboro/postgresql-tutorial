-- =====================================================================
-- 17장. 사용자와 권한 - ROLE, GRANT, 행 수준 보안(RLS)
--   superuser(postgres)로 실행합니다. ROLE 은 데이터베이스가 아닌 서버 전체에 만들어집니다.
-- =====================================================================
-- 이전 실습에서 만든 역할이 남아 있으면 지우고 시작
DO $$
DECLARE r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['analyst', 'app_user', 'sales_kang', 'sales_cho', 'readonly'] LOOP
        IF EXISTS (SELECT FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END $$;
DROP TABLE IF EXISTS sales_reps;

-- @ex 17-01 ROLE 만들기 - 로그인 가능한 사용자와 그룹 역할
CREATE ROLE readonly NOLOGIN;                               -- 권한 묶음(그룹)
CREATE ROLE analyst  LOGIN PASSWORD 'analyst123';           -- 실습용 비밀번호
CREATE ROLE app_user LOGIN PASSWORD 'app123' CONNECTION LIMIT 20;
GRANT readonly TO analyst;                                  -- analyst 는 readonly 의 권한을 상속
SELECT rolname, rolcanlogin, rolsuper, rolconnlimit
FROM pg_roles WHERE rolname IN ('readonly', 'analyst', 'app_user') ORDER BY rolname;

-- @ex 17-02 권한이 없으면 조회할 수 없다 [error]
SET ROLE analyst;
SELECT current_user;
SELECT count(*) FROM customers;
RESET ROLE;

-- @ex 17-03 GRANT - 읽기 전용 권한 부여
GRANT USAGE  ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
-- 앞으로 새로 만들 테이블에도 자동 적용
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
SET ROLE analyst;
SELECT count(*) AS 고객수 FROM customers;
RESET ROLE;

-- @ex 17-04 읽기 전용 사용자는 수정할 수 없다 [error]
SET ROLE analyst;
UPDATE customers SET grade = 'VIP' WHERE customer_id = 2;
RESET ROLE;

-- @ex 17-05 컬럼 단위 권한 - 앱 계정은 필요한 컬럼만
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT (product_id, name, price, stock) ON products TO app_user;
GRANT UPDATE (stock) ON products TO app_user;
SET ROLE app_user;
SELECT product_id, name, stock FROM products WHERE product_id = 1;
UPDATE products SET stock = stock - 1 WHERE product_id = 1;
RESET ROLE;

-- @ex 17-06 허용되지 않은 컬럼 접근 [error]
SET ROLE app_user;
SELECT attrs FROM products WHERE product_id = 1;
UPDATE products SET price = 1 WHERE product_id = 1;
RESET ROLE;

-- @ex 17-07 권한 확인과 회수(REVOKE)
SELECT grantee, privilege_type, count(*) AS 테이블수
FROM information_schema.role_table_grants
WHERE grantee IN ('readonly', 'app_user')
GROUP BY grantee, privilege_type ORDER BY 1, 2;
SELECT grantee, column_name, privilege_type          -- 컬럼 권한은 별도 뷰에 있다
FROM information_schema.column_privileges
WHERE grantee = 'app_user' ORDER BY privilege_type, column_name;
REVOKE UPDATE (stock) ON products FROM app_user;

-- @ex 17-08 행 수준 보안(RLS) - 영업사원은 자기 담당 주문만 보기
CREATE ROLE sales_kang LOGIN PASSWORD 'kang123';            -- 직원 6번 강민수
CREATE ROLE sales_cho  LOGIN PASSWORD 'cho123';             -- 직원 7번 조은지
CREATE TABLE sales_reps (                                   -- DB 계정 ↔ 직원 번호 매핑
    role_name NAME PRIMARY KEY,
    emp_id    INTEGER NOT NULL REFERENCES employees
);
INSERT INTO sales_reps VALUES ('sales_kang', 6), ('sales_cho', 7);
GRANT USAGE ON SCHEMA public TO sales_kang, sales_cho;
GRANT SELECT ON orders, sales_reps TO sales_kang, sales_cho;

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY orders_by_owner ON orders
    FOR SELECT
    USING (emp_id = (SELECT emp_id FROM sales_reps WHERE role_name = current_user));

SET ROLE sales_kang;
SELECT current_user, count(*) AS 보이는주문, min(emp_id), max(emp_id) FROM orders;
RESET ROLE;
SET ROLE sales_cho;
SELECT current_user, count(*) AS 보이는주문, min(emp_id), max(emp_id) FROM orders;
RESET ROLE;
SELECT current_user, count(*) AS 보이는주문 FROM orders;    -- 테이블 소유자/superuser 는 전체

-- @ex 17-09 정리 - RLS 해제와 역할 삭제
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
DROP POLICY orders_by_owner ON orders;
DROP OWNED BY sales_kang, sales_cho;      -- 부여된 권한 제거
DROP ROLE sales_kang, sales_cho;
SELECT count(*) AS 남은sales역할 FROM pg_roles WHERE rolname LIKE 'sales_%';
