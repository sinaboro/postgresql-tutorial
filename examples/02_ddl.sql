-- =====================================================================
-- 02장. 테이블 만들기 - 자료형과 제약 조건 (DDL)
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS members, notices, enrollments, students, courses, typetest CASCADE;
RESET client_min_messages;

-- @ex 02-01 가장 단순한 테이블 만들기
CREATE TABLE notices (
    id      INTEGER,
    title   VARCHAR(100),
    content TEXT
);
\d notices

-- @ex 02-02 자주 쓰는 자료형 맛보기
CREATE TABLE typetest (
    a_int     INTEGER,          -- 정수 (약 ±21억)
    a_big     BIGINT,           -- 큰 정수
    a_num     NUMERIC(8,2),     -- 정확한 소수 (전체 8자리, 소수 2자리)
    a_real    DOUBLE PRECISION, -- 근사 실수
    a_char    CHAR(5),          -- 고정 길이 문자
    a_varchar VARCHAR(10),      -- 가변 길이 문자 (최대 10자)
    a_text    TEXT,             -- 길이 제한 없는 문자
    a_bool    BOOLEAN,
    a_date    DATE,
    a_ts      TIMESTAMP,
    a_tstz    TIMESTAMPTZ       -- 시간대 포함 타임스탬프
);
INSERT INTO typetest VALUES
    (2147483647, 9223372036854775807, 123456.789, 0.1 + 0.2,
     'ab', '가나다', '아주 긴 글도 저장 가능', true,
     '2026-10-23', '2026-10-23 14:30:00', '2026-10-23 14:30:00+09');
SELECT a_num, a_real, '[' || a_char || ']' AS a_char, length(a_char) AS char_len, a_bool, a_tstz
FROM typetest;

-- @ex 02-03 범위를 벗어난 값은 오류 [error]
INSERT INTO typetest (a_int) VALUES (2147483648);
INSERT INTO typetest (a_varchar) VALUES ('열한글자를넘는긴문자열');

-- @ex 02-04 NUMERIC 과 실수형의 차이 (돈 계산은 NUMERIC!)
SELECT 0.1::double precision + 0.2::double precision = 0.3 AS 실수비교,
       0.1::numeric + 0.2::numeric = 0.3 AS 숫자비교;

-- @ex 02-05 제약 조건을 갖춘 테이블 - PK, NOT NULL, UNIQUE, CHECK, DEFAULT
CREATE TABLE members (
    member_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      VARCHAR(100) NOT NULL UNIQUE,
    name       VARCHAR(50)  NOT NULL,
    age        INTEGER CHECK (age BETWEEN 0 AND 150),
    level      VARCHAR(10)  NOT NULL DEFAULT 'NORMAL',
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);
INSERT INTO members (email, name, age) VALUES ('a@test.com', '홍길동', 30);
SELECT member_id, email, name, age, level FROM members;

-- @ex 02-06 제약 조건 위반 사례 [error]
INSERT INTO members (email, name, age) VALUES ('a@test.com', '중복이메일', 20);  -- UNIQUE
INSERT INTO members (email, age) VALUES ('b@test.com', 25);                  -- NOT NULL
INSERT INTO members (email, name, age) VALUES ('c@test.com', '나이오류', 200); -- CHECK

-- @ex 02-07 외래 키(FOREIGN KEY)로 테이블 연결
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY,
    name       VARCHAR(50) NOT NULL
);
CREATE TABLE courses (
    course_id  INTEGER PRIMARY KEY,
    title      VARCHAR(100) NOT NULL
);
CREATE TABLE enrollments (
    student_id INTEGER REFERENCES students (student_id) ON DELETE CASCADE,
    course_id  INTEGER REFERENCES courses (course_id),
    enrolled_on DATE NOT NULL DEFAULT current_date,
    PRIMARY KEY (student_id, course_id)          -- 복합 기본 키
);
INSERT INTO students VALUES (1, '김학생'), (2, '이학생');
INSERT INTO courses  VALUES (10, 'PostgreSQL 기초'), (20, '파이썬');
INSERT INTO enrollments (student_id, course_id) VALUES (1, 10), (1, 20), (2, 10);
SELECT student_id, course_id FROM enrollments ORDER BY 1, 2;

-- @ex 02-08 존재하지 않는 부모를 참조하면 오류 [error]
INSERT INTO enrollments (student_id, course_id) VALUES (3, 10);

-- @ex 02-09 ON DELETE CASCADE - 부모를 지우면 자식도 함께 삭제
DELETE FROM students WHERE student_id = 1;
SELECT student_id, course_id FROM enrollments;

-- @ex 02-10 ALTER TABLE - 컬럼 추가/변경/삭제, 이름 바꾸기
ALTER TABLE notices ADD COLUMN created_at TIMESTAMP DEFAULT now();
ALTER TABLE notices ALTER COLUMN title SET NOT NULL;
ALTER TABLE notices ALTER COLUMN title TYPE VARCHAR(200);
ALTER TABLE notices ADD PRIMARY KEY (id);
ALTER TABLE notices RENAME COLUMN content TO body;
ALTER TABLE notices DROP COLUMN created_at;
\d notices

-- @ex 02-11 제약 조건에 이름 붙이고 추가/삭제하기
ALTER TABLE members ADD CONSTRAINT chk_members_level
    CHECK (level IN ('NORMAL', 'SILVER', 'GOLD'));
SELECT conname, contype   -- p: 기본키, u: 유니크, c: 체크, f: 외래키
FROM pg_constraint
WHERE conrelid = 'members'::regclass
ORDER BY conname;
ALTER TABLE members DROP CONSTRAINT chk_members_level;

-- @ex 02-12 TRUNCATE 와 DROP TABLE
TRUNCATE TABLE typetest;               -- 데이터만 모두 삭제 (구조는 유지)
SELECT count(*) FROM typetest;
DROP TABLE typetest;                   -- 테이블 자체를 삭제
DROP TABLE IF EXISTS typetest;         -- 없어도 오류 없이 넘어감
