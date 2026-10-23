"""모든 예제/정답 SQL 을 새 shop DB 에서 실행해 예상하지 못한 오류가 없는지 검사한다.

    python tools/verify.py                 # 전체 검사
    python tools/verify.py examples/07*    # 일부만 검사
    python tools/verify.py -v examples/07_join.sql   # 블록별 출력까지 보기
"""
import glob
import sys

import runner

args = [a for a in sys.argv[1:] if a != "-v"]
verbose = "-v" in sys.argv
files = []
for pat in args or ["examples/*.sql", "solutions/*.sql"]:
    files += sorted(glob.glob(str(runner.ROOT / pat)) or glob.glob(pat))

failed = 0
for f in files:
    blocks = runner.run(f)
    bad = runner.problems(blocks)
    failed += len(bad)
    print(f"{'FAIL' if bad else 'ok  '} {f}  ({len(blocks)} blocks)")
    for b in blocks if verbose else bad:
        print(f"--- [{b.id}] {b.title}{' [error 예상]' if b.expect_error else ''}")
        print(b.output)
sys.exit(1 if failed else 0)
