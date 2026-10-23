-- =====================================================================
-- 14장. 트랜잭션과 동시성 - ACID, 격리 수준, 잠금
--   두 세션이 필요한 실험은 psql 창 2개로 따라 하거나 python/05_concurrency_demo.py 로 확인
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS accounts;
RESET client_min_messages;
CREATE TABLE accounts (
    account_id INTEGER PRIMARY KEY,
    owner      VARCHAR(20) NOT NULL,
    balance    NUMERIC(12,0) NOT NULL CHECK (balance >= 0)
);
INSERT INTO accounts VALUES (1, '김철수', 100000), (2, '이영희', 50000);

-- @ex 14-01 트랜잭션 - 계좌 이체는 두 UPDATE 가 함께 성공해야 한다
BEGIN;
UPDATE accounts SET balance = balance - 30000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 30000 WHERE account_id = 2;
COMMIT;
SELECT * FROM accounts ORDER BY account_id;

-- @ex 14-02 ROLLBACK - 진행 중인 변경을 모두 취소
BEGIN;
DELETE FROM accounts;
SELECT count(*) AS 삭제후 FROM accounts;
ROLLBACK;
SELECT count(*) AS 롤백후 FROM accounts;

-- @ex 14-03 원자성(Atomicity) - 잔액 부족으로 두 번째 문장이 실패하면? [error]
BEGIN;
UPDATE accounts SET balance = balance + 999999 WHERE account_id = 2;  -- 입금 먼저 (성공)
UPDATE accounts SET balance = balance - 999999 WHERE account_id = 1;  -- CHECK 위반 (실패)
SELECT * FROM accounts;          -- 오류 이후에는 어떤 명령도 거부된다
COMMIT;                          -- COMMIT 을 해도 실제로는 ROLLBACK 된다

-- @ex 14-04 실패한 트랜잭션은 전부 취소되었다
SELECT * FROM accounts ORDER BY account_id;

-- @ex 14-05 SAVEPOINT - 일부만 되돌리기
BEGIN;
UPDATE accounts SET balance = balance + 1000 WHERE account_id = 1;
SAVEPOINT sp1;
UPDATE accounts SET balance = balance + 5000 WHERE account_id = 2;
ROLLBACK TO SAVEPOINT sp1;       -- sp1 이후 작업만 취소
COMMIT;
SELECT * FROM accounts ORDER BY account_id;

-- @ex 14-06 격리 수준 확인과 설정
SHOW transaction_isolation;      -- 기본값: read committed
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
COMMIT;

-- @ex 14-07 MVCC - 행마다 숨어 있는 버전 정보(xmin, xmax)
SELECT xmin, xmax, account_id, balance FROM accounts ORDER BY account_id;
UPDATE accounts SET balance = balance WHERE account_id = 1;   -- 값이 같아도 새 버전 생성
SELECT xmin, xmax, account_id, balance FROM accounts ORDER BY account_id;

-- @ex 14-08 행 잠금 - SELECT ... FOR UPDATE 와 pg_locks
BEGIN;
SELECT * FROM accounts WHERE account_id = 1 FOR UPDATE;   -- 다른 세션은 이 행 수정 시 대기
SELECT l.locktype, l.mode, l.granted
FROM pg_locks l
WHERE l.relation = 'accounts'::regclass AND l.pid = pg_backend_pid();
COMMIT;

-- @ex 14-09 갱신 손실 방지 - 읽고 계산하지 말고 한 문장으로 갱신
-- (나쁜 예) SELECT balance … → 앱에서 계산 → UPDATE SET balance = 계산값
-- (좋은 예) 데이터베이스가 원자적으로 계산
UPDATE accounts SET balance = balance - 10000
WHERE account_id = 1 AND balance >= 10000
RETURNING account_id, balance;

-- @ex 14-10 잠금 대기 시간 제한 - lock_timeout / NOWAIT
SET lock_timeout = '3s';
SHOW lock_timeout;
BEGIN;
SELECT account_id FROM accounts WHERE account_id = 2 FOR UPDATE NOWAIT;  -- 잠겨 있으면 즉시 오류
COMMIT;
RESET lock_timeout;
