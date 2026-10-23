-- =====================================================================
-- 18장. 운영 기초 - 모니터링, 설정, VACUUM, 확장, 백업/복구, 데이터 입출력
--   백업 명령(pg_dump 등)은 psql 이 아니라 터미널(명령 프롬프트)에서 실행합니다. (교안 참고)
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS vac_test, customers_import;
RESET client_min_messages;

-- @ex 18-01 데이터베이스와 테이블 크기
SELECT pg_size_pretty(pg_database_size(current_database())) AS db크기;
SELECT relname AS 테이블,
       pg_size_pretty(pg_total_relation_size(relid)) AS 전체크기,
       pg_size_pretty(pg_relation_size(relid))       AS 데이터,
       pg_size_pretty(pg_indexes_size(relid))        AS 인덱스
FROM pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 5;

-- @ex 18-02 현재 접속 중인 세션 보기 - pg_stat_activity
SELECT usename, datname, state, backend_type,
       left(query, 40) AS query
FROM pg_stat_activity
WHERE datname = current_database();

-- @ex 18-03 문제 세션 정리 - 쿼리 취소와 강제 종료 (사용법)
-- SELECT pg_cancel_backend(12345);     -- 실행 중인 쿼리만 취소
-- SELECT pg_terminate_backend(12345);  -- 접속 자체를 끊음
-- 5분 이상 'idle in transaction' 인 세션 찾기
SELECT pid, usename, state, now() - state_change AS 지속시간
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 minutes';

-- @ex 18-04 서버 설정 확인 - SHOW 와 pg_settings
SHOW max_connections;
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem',
               'effective_cache_size', 'autovacuum', 'timezone')
ORDER BY name;

-- @ex 18-05 설정 바꾸기 - 세션 / 데이터베이스 / 서버 단위
SET work_mem = '64MB';                          -- 현재 세션만
SHOW work_mem;
RESET work_mem;
ALTER DATABASE shop SET statement_timeout = '60s';   -- 이 DB 에 새로 접속하는 세션부터
ALTER DATABASE shop RESET statement_timeout;
-- ALTER SYSTEM SET work_mem = '16MB';  SELECT pg_reload_conf();   -- 서버 전체 (postgresql.auto.conf)

-- @ex 18-06 MVCC 의 부산물 - 죽은 튜플(dead tuple)과 VACUUM
CREATE TABLE vac_test AS SELECT g AS id, 'x' AS v FROM generate_series(1, 100000) g;
UPDATE vac_test SET v = 'y';                    -- 10만 행 모두 새 버전 생성
SELECT pg_stat_force_next_flush();              -- 통계를 즉시 반영 (실습용)
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'vac_test';
VACUUM vac_test;
SELECT pg_stat_force_next_flush();
SELECT relname, n_live_tup, n_dead_tup, last_vacuum IS NOT NULL AS vacuum됨
FROM pg_stat_user_tables WHERE relname = 'vac_test';

-- @ex 18-07 ANALYZE 와 통계 정보 - 옵티마이저가 보는 값
ANALYZE orders;
SELECT attname, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';

-- @ex 18-08 확장(Extension) - pgcrypto 로 비밀번호 해시, UUID 생성
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT gen_random_uuid() IS NOT NULL AS uuid생성,               -- 13 버전부터 기본 내장
       length(crypt('my-password', gen_salt('bf'))) AS 해시길이,
       crypt('my-password', '$2a$06$abcdefghijklmnopqrstuu')
           = crypt('my-password', '$2a$06$abcdefghijklmnopqrstuu') AS 같은솔트같은해시;
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- @ex 18-09 [설정 필요] pg_stat_statements - 느린/자주 실행되는 쿼리 찾기
-- postgresql.conf 에 shared_preload_libraries = 'pg_stat_statements' 추가 후 서버 재시작 필요
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT calls, round(mean_exec_time::numeric, 2) AS 평균ms, left(query, 50) AS query
FROM pg_stat_statements
WHERE query ILIKE 'select%orders%'
ORDER BY total_exec_time DESC
LIMIT 3;

-- @ex 18-10 데이터 내보내기/가져오기 - \copy (CSV)
\copy (SELECT customer_id, name, city, grade FROM customers ORDER BY customer_id) TO 'customers_export.csv' WITH (FORMAT csv, HEADER)
CREATE TABLE customers_import (customer_id INT, name TEXT, city TEXT, grade TEXT);
\copy customers_import FROM 'customers_export.csv' WITH (FORMAT csv, HEADER)
SELECT count(*) AS 가져온행수, min(name), max(name) FROM customers_import;
