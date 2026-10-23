-- =====================================================================
-- 01장. PostgreSQL 시작하기 - 접속, psql, 첫 번째 쿼리
--   실행: psql -U postgres -d shop -f examples/01_intro.sql
-- =====================================================================

-- @ex 01-01 서버 버전과 접속 정보 확인
SHOW server_version;
SELECT current_database(), current_user;

-- @ex 01-02 SQL 은 계산기처럼도 쓸 수 있다
SELECT 1 + 2 AS 더하기,
       10 / 3 AS 정수나눗셈,
       10 / 3.0 AS 실수나눗셈,
       2 ^ 10 AS 거듭제곱,
       'Postgre' || 'SQL' AS 문자열연결;

-- @ex 01-03 psql 메타 명령: 테이블 목록 (\dt)
\dt

-- @ex 01-04 psql 메타 명령: 테이블 구조 보기 (\d 테이블명)
\d departments

-- @ex 01-05 첫 번째 SELECT - 부서 테이블 전체 조회
SELECT * FROM departments;

-- @ex 01-06 SQL 은 대소문자를 구분하지 않는다 (문자열 값은 구분)
select NAME, Location from DEPARTMENTS where location = '서울';
SELECT name FROM departments WHERE location = 'SEOUL';

-- @ex 01-07 주석 작성법
-- 한 줄 주석은 하이픈 두 개
/* 여러 줄 주석은
   C 언어 스타일 */
SELECT name /* 이름만 */ FROM departments WHERE dept_id = 1;
