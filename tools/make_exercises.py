"""solutions/*.sql 에서 문제 문장만 뽑아 exercises/*.sql (수강생 배포용 문제지)을 만든다.

    python tools/make_exercises.py
"""
from pathlib import Path

import runner

for src in sorted((runner.ROOT / "solutions").glob("*_solutions.sql")):
    prelude, blocks = runner.parse(src)
    chapters = sorted({b.id.split("-")[0] for b in blocks})
    out = [
        "-- =====================================================================",
        f"-- 실습 문제 : {chapters[0]}장 ~ {chapters[-1]}장   (정답: solutions/{src.name})",
        "--   각 문제 아래에 SQL 을 작성하고 실행해 보세요.",
        "-- =====================================================================",
        "",
    ]
    for b in blocks:
        title = b.title.replace(" [error]", "")
        out += [f"-- [{b.id}] {title}", "", "", ""]
    dst = runner.ROOT / "exercises" / src.name.replace("_solutions", "_exercises")
    dst.write_text("\n".join(out), encoding="utf-8")
    print(f"{dst.relative_to(runner.ROOT)}: {len(blocks)} 문제")
