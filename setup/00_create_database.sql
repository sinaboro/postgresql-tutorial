-- =====================================================================
-- 실습 데이터베이스 만들기 (postgres 계정으로 접속한 상태에서 실행)
--
--   psql -U postgres -f setup/00_create_database.sql
--
-- 이후 순서
--   psql -U postgres -d shop -f setup/01_schema.sql
--   psql -U postgres -d shop -f setup/02_seed.sql
-- =====================================================================

DROP DATABASE IF EXISTS shop;
CREATE DATABASE shop ENCODING 'UTF8' TEMPLATE template0;
