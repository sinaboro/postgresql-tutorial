"""예제 SQL 파일을 psql 로 실행하고, 예제 블록별 출력을 모은다.

예제 파일 규칙
    -- @ex 04-01 제목            ← 여기부터 다음 @ex 까지가 예제 하나
    -- @ex 02-07 제목 [error]    ← 일부러 오류를 보여 주는 예제 (검증 시 오류를 허용)
    첫 @ex 앞에 있는 SQL 은 준비 코드로 실행만 하고 교안에는 넣지 않는다.

접속 정보는 표준 libpq 환경변수(PGHOST, PGPORT, PGUSER, PGPASSWORD)를 쓰고,
psql 실행 파일 경로는 PSQL 환경변수로 바꿀 수 있다.
"""
import os
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PSQL = os.environ.get("PSQL", "psql")
DB = os.environ.get("SHOP_DB", "shop")
MARK = re.compile(r"^--\s*@ex\s+(\S+)\s+(.*?)\s*(\[error\])?\s*$")


@dataclass
class Block:
    id: str
    title: str
    sql: str
    expect_error: bool = False
    output: str = ""
    lines: list = field(default_factory=list)


def psql(args, stdin=None, db=DB):
    # LANG=C: 한국어 Windows 에서도 메시지를 영어로 (교안 출력 통일, 검색하기 쉬움)
    env = dict(os.environ, PGCLIENTENCODING="UTF8", LANG="C")
    cmd = [PSQL, "-X", "-d", db, "-P", "pager=off", *args]
    p = subprocess.run(cmd, input=stdin, capture_output=False, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, env=env, cwd=ROOT)
    return p.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n")


def reset_db():
    """shop 데이터베이스를 지우고 스키마 + 샘플 데이터를 새로 넣는다."""
    psql(["-q", "-c", f"DROP DATABASE IF EXISTS {DB} WITH (FORCE)"], db="postgres")
    create = f"CREATE DATABASE {DB}"
    if os.environ.get("SHOP_LOCALE"):     # 예: Korean_Korea.949 (한국어 Windows 설치 기본값과 동일하게)
        create += (f" TEMPLATE template0 ENCODING 'UTF8' LOCALE_PROVIDER libc"
                   f" LOCALE '{os.environ['SHOP_LOCALE']}'")
    psql(["-q", "-c", create], db="postgres")
    # 교안의 시간 출력이 한국 시간 기준이 되도록 (설치 시 기본값도 보통 Asia/Seoul)
    psql(["-q", "-c", f"ALTER DATABASE {DB} SET timezone = 'Asia/Seoul'"], db="postgres")
    out = psql(["-q", "-v", "ON_ERROR_STOP=1", "-f", "setup/01_schema.sql",
                "-f", "setup/02_seed.sql"])
    if "ERROR" in out:
        raise RuntimeError(out)


def parse(path):
    prelude, blocks, cur = [], [], None
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = MARK.match(line)
        if m:
            cur = Block(m.group(1), m.group(2), "", bool(m.group(3)))
            blocks.append(cur)
        elif cur is None:
            prelude.append(line)
        else:
            cur.lines.append(line)
    for b in blocks:
        b.sql = "\n".join(b.lines).strip("\n")
    return "\n".join(prelude), blocks


_prefix = re.compile(r"^psql:[^\n]*?:\d+: ", re.M)


def run(path, reset=True):
    """파일 전체를 한 세션에서 순서대로 실행하고 블록별 출력을 채운 Block 목록을 돌려준다."""
    if reset:
        reset_db()
    prelude, blocks = parse(path)
    script = ["\\set QUIET on", prelude, "\\set QUIET off"]
    for b in blocks:
        script += [f"\\echo '@@BEGIN {b.id}'", b.sql, f"\\echo '@@END {b.id}'"]
    out = psql(["-f", "-"], stdin="\n".join(script).encode("utf-8"))
    out = _prefix.sub("", out)
    for b in blocks:
        m = re.search(rf"@@BEGIN {re.escape(b.id)}\n(.*?)@@END {re.escape(b.id)}\n", out, re.S)
        b.output = m.group(1).rstrip("\n") if m else "(출력을 찾지 못함)"
    return blocks


def problems(blocks):
    """검증: 예상하지 못한 오류가 난 블록 목록."""
    bad = []
    for b in blocks:
        has_err = bool(re.search(r"^(ERROR|FATAL):", b.output, re.M))
        if has_err != b.expect_error or b.output == "(출력을 찾지 못함)":
            bad.append(b)
    return bad
