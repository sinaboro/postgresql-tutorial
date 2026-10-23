# 부록 A ∙ 실습 문제 정답

정답 SQL 은 `solutions/` 폴더에 있고, 아래 실행 결과는 각 정답 파일을 새로 초기화한 shop DB 에서 순서대로 실행한 것입니다. 앞 문제에서 만든 테이블을 뒤 문제에서 쓰는 경우가 있으므로 같은 파일 안에서는 순서대로 실행하세요. 정답은 하나가 아닙니다. 결과가 같다면 다른 풀이도 정답으로 인정하고, 서로의 풀이를 비교해 보게 하세요.

@@answers

# 부록 B ∙ 빠른 참조

## SQL 문법 요약

| 분류 | 문법 |
|---|---|
| 테이블 생성 | `CREATE TABLE t (id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, ...)` |
| 컬럼 추가 | `ALTER TABLE t ADD COLUMN c TYPE` |
| 입력 | `INSERT INTO t (a, b) VALUES (1, 2) RETURNING *` |
| UPSERT | `INSERT ... ON CONFLICT (키) DO UPDATE SET c = EXCLUDED.c` |
| 수정 / 삭제 | `UPDATE t SET c = v WHERE ...` / `DELETE FROM t WHERE ...` |
| 조회 | `SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT n` |
| 조인 | `FROM a JOIN b ON a.k = b.k LEFT JOIN c ON ...` |
| CTE | `WITH x AS (SELECT ...) SELECT ... FROM x` |
| 재귀 | `WITH RECURSIVE x AS (앵커 UNION ALL 재귀부) ...` |
| 윈도우 | `함수() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN ...)` |
| 인덱스 | `CREATE INDEX 이름 ON t (a, b)` / `USING GIN (jsonb컬럼)` |
| 실행 계획 | `EXPLAIN (ANALYZE, BUFFERS) 쿼리` |
| 트랜잭션 | `BEGIN; ... COMMIT;` / `ROLLBACK;` / `SAVEPOINT s; ROLLBACK TO s;` |
| 권한 | `GRANT SELECT ON t TO 롤;` / `REVOKE ...` |

## 자주 만나는 오류 메시지

| 메시지 | 원인 | 해결 |
|---|---|---|
| `relation "xxx" does not exist` | 테이블 이름 오타, 다른 DB/스키마에 접속, 대소문자(따옴표) | `\c shop`, `\dt`, search_path 확인 |
| `column "xxx" does not exist` | 컬럼 오타, 문자열을 큰따옴표로 씀(`"서울"`) | 문자열 값은 작은따옴표 |
| `syntax error at or near "xxx"` | 쉼표·괄호 누락, 예약어 사용 | 표시된 위치 바로 앞을 확인 |
| `must appear in the GROUP BY clause` | GROUP BY 규칙 위반 (6장) | GROUP BY 에 추가 또는 집계 함수 |
| `duplicate key value violates unique constraint` | PK/UNIQUE 중복 | 값 확인, UPSERT 고려 |
| `violates foreign key constraint` | 없는 부모 참조 / 자식이 있는 부모 삭제 | 부모 먼저 입력 / 자식 먼저 삭제 |
| `current transaction is aborted` | 트랜잭션 안에서 앞서 오류 발생 (14장) | `ROLLBACK;` |
| `operator does not exist: integer \|\| integer` 등 | 자료형 불일치 | `::text` 등 형변환 |
| `division by zero` | 0 으로 나눔 | `NULLIF(분모, 0)` |
| `permission denied for table` | 권한 없음 (17장) | GRANT, 스키마 USAGE 확인 |
| `password authentication failed` | 비밀번호 오류, pg_hba.conf | 1장 설치 문제 해결 참고 |
| `could not connect to server` | 서비스 중지, 포트 오류 | 서비스(services.msc) 실행, 포트 확인 |

## psql 메타 명령

| 명령 | 의미 | 명령 | 의미 |
|---|---|---|---|
| `\l` | DB 목록 | `\c db` | DB 전환 |
| `\dt [패턴]` | 테이블 | `\d t` | 테이블 구조 |
| `\dv` / `\dm` | 뷰 / 머티리얼라이즈드 뷰 | `\di` | 인덱스 |
| `\dn` | 스키마 | `\df` | 함수 |
| `\du` | 롤 | `\dx` | 설치된 확장 |
| `\x` | 세로 출력 전환 | `\timing` | 실행 시간 표시 |
| `\i 파일` | 파일 실행 | `\o 파일` | 출력을 파일로 |
| `\copy` | CSV 입출력 (18장) | `\e` | 편집기 |
| `\conninfo` | 접속 정보 | `\q` | 종료 |

## 교안 재생성 방법 (강사용)

예제나 샘플 데이터를 고친 뒤에는 다음 순서로 검증하고 이 PDF 를 다시 만들 수 있습니다. 모든 실행 결과가 새로 채워집니다.

```
set PGHOST=localhost
set PGUSER=postgres
set PGPASSWORD=비밀번호
python tools/gen_seed.py          (샘플 데이터를 바꿨을 때만)
python tools/verify.py            (모든 예제·정답이 예상대로 실행되는지 검사)
python tools/make_exercises.py    (정답 파일에서 문제지 생성)
python tools/build_guide.py       (docs/PostgreSQL_강사용교안.pdf 생성)
```
