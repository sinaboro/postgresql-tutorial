"""강사용 교안 PDF 빌더.

docs/guide/*.md 원고를 읽고, 원고 속 지시어(@@ex 등)가 가리키는 예제를 실제 PostgreSQL 에서
실행해 그 출력을 그대로 넣어 docs/PostgreSQL_강사용교안.pdf 를 만든다.

    python tools/build_guide.py

필요한 것
  - 실행 중인 PostgreSQL (PGHOST/PGPORT/PGUSER/PGPASSWORD 환경변수), psql (PSQL 환경변수)
  - pip install reportlab matplotlib psycopg[binary] pandas
  - 글꼴: 맑은 고딕(Windows 기본), D2Coding(https://github.com/naver/d2codingfont)
          D2Coding 위치는 D2CODING_DIR 환경변수 또는 tools/fonts/ 에서 찾는다.

원고 문법 (마크다운의 일부 + 지시어)
  # 장 제목 / ## 절 / ### 소절, 문단, - 목록, 1. 번호 목록, | 표 |, ``` 코드 ```
  > [!TEACH] 제목   강사 노트 상자 (TIP, WARN, NOTE 도 가능), 이어지는 '> ' 줄이 본문
  @@ex 04-01 04-02     예제 코드 + 실행 결과
  @@code 13-05         예제 코드만
  @@py python/01_connect.py   파이썬 코드 + 실행 결과
  @@q 04-Q1 04-Q2      실습 문제 목록 (정답은 부록)
  @@answers            부록: 모든 실습 문제 정답과 실행 결과
  @@image docs/images/erd.png 160   그림 (폭 mm)
  @@pagebreak
"""
import glob
import os
import re
import subprocess
import sys
import unicodedata
from datetime import date
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable, Frame, Image,
                                KeepTogether, NextPageTemplate, PageBreak, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

sys.path.insert(0, str(Path(__file__).parent))
import runner  # noqa: E402

ROOT = runner.ROOT
OUT = ROOT / "docs" / "PostgreSQL_강사용교안.pdf"
TITLE = "PostgreSQL 데이터베이스"
INSTRUCTOR = "김대철"
REPO = "github.com/sinaboro/postgresql-tutorial"

# ---------------------------------------------------------------- 글꼴
def find_font(name, dirs):
    for d in dirs:
        hits = glob.glob(os.path.join(d, "**", name), recursive=True)
        if hits:
            return hits[0]
    raise SystemExit(f"글꼴을 찾을 수 없습니다: {name} (D2CODING_DIR 환경변수를 확인하세요)")


font_dirs = [os.environ.get("D2CODING_DIR", ""), str(ROOT / "tools" / "fonts"), "C:/Windows/Fonts"]
pdfmetrics.registerFont(TTFont("Body", find_font("malgun.ttf", font_dirs)))
pdfmetrics.registerFont(TTFont("BodyB", find_font("malgunbd.ttf", font_dirs)))
pdfmetrics.registerFont(TTFont("Mono", find_font("D2Coding-Ver*.ttf", font_dirs)))
pdfmetrics.registerFont(TTFont("MonoB", find_font("D2CodingBold-Ver*.ttf", font_dirs)))
pdfmetrics.registerFontFamily("Body", normal="Body", bold="BodyB", italic="Body", boldItalic="BodyB")
pdfmetrics.registerFontFamily("Mono", normal="Mono", bold="MonoB", italic="Mono", boldItalic="MonoB")

# ---------------------------------------------------------------- 색과 스타일
NAVY = colors.HexColor("#1f3a5f")
BLUE = colors.HexColor("#336791")          # PostgreSQL 코끼리 색
LIGHT = colors.HexColor("#eef3f8")
CODE_BG = colors.HexColor("#f6f8fa")
OUT_BG = colors.HexColor("#fbfbf3")
GREY = colors.HexColor("#6b7280")
BOX = {
    "TEACH": ("강사 노트", colors.HexColor("#fff4e5"), colors.HexColor("#e8890c")),
    "TIP":   ("TIP",      colors.HexColor("#e8f4fd"), colors.HexColor("#2b7bb9")),
    "WARN":  ("주의",     colors.HexColor("#fdecec"), colors.HexColor("#c0392b")),
    "NOTE":  ("참고",     colors.HexColor("#f2f2f2"), colors.HexColor("#7f8c8d")),
    "QA":    ("예상 질문", colors.HexColor("#f0f7ee"), colors.HexColor("#3c8d2f")),
}

S = {}
S["body"] = ParagraphStyle("body", fontName="Body", fontSize=9.6, leading=15.5, spaceAfter=4.5)
S["small"] = ParagraphStyle("small", parent=S["body"], fontSize=8.5, leading=13, spaceAfter=2)
S["bullet"] = ParagraphStyle("bullet", parent=S["body"], leftIndent=13, bulletIndent=3, spaceAfter=2)
S["bullet2"] = ParagraphStyle("bullet2", parent=S["bullet"], leftIndent=26, bulletIndent=16)
S["h1"] = ParagraphStyle("h1", fontName="BodyB", fontSize=19, leading=25, textColor=colors.white)
S["h2"] = ParagraphStyle("h2", fontName="BodyB", fontSize=13.5, leading=19, textColor=NAVY,
                         spaceBefore=12, spaceAfter=5)
S["h3"] = ParagraphStyle("h3", fontName="BodyB", fontSize=11, leading=16, textColor=BLUE,
                         spaceBefore=8, spaceAfter=3)
S["cell"] = ParagraphStyle("cell", fontName="Body", fontSize=8.6, leading=12.5)
S["cellh"] = ParagraphStyle("cellh", parent=S["cell"], fontName="BodyB", textColor=colors.white)
S["boxtitle"] = ParagraphStyle("boxtitle", fontName="BodyB", fontSize=9.2, leading=13)
S["boxbody"] = ParagraphStyle("boxbody", parent=S["body"], fontSize=9, leading=14, spaceAfter=2)
S["extitle"] = ParagraphStyle("extitle", fontName="BodyB", fontSize=9.2, leading=13, textColor=colors.white)
S["label"] = ParagraphStyle("label", fontName="BodyB", fontSize=7.8, leading=10, textColor=GREY)
S["toc1"] = ParagraphStyle("toc1", fontName="BodyB", fontSize=10.5, leading=17, leftIndent=0)
S["toc2"] = ParagraphStyle("toc2", fontName="Body", fontSize=9, leading=13.5, leftIndent=16,
                           textColor=colors.HexColor("#374151"))

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm
TEXT_W = PAGE_W - 2 * MARGIN


def inline(text):
    """**굵게**, `코드` 를 ReportLab 마크업으로."""
    text = re.sub(r"\*\*(.+?)\*\*", "\x01\\1\x02", text)       # 굵게 안에 `코드` 가 있어도 되도록
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for p in parts:
        if p.startswith("`") and p.endswith("`") and len(p) > 1:
            out.append(f'<font name="Mono" color="#b5245e">{escape(p[1:-1])}</font>')
        else:
            p = escape(p)
            p = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", p)
            p = p.replace("\\", '<font name="Mono">\\</font>')   # 맑은 고딕은 \ 를 ₩ 로 그린다
            out.append(p)
    return "".join(out).replace("\x01", "<b>").replace("\x02", "</b>")


def disp_width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


# ---------------------------------------------------------------- 코드 상자
def code_table(text, bg, border, label=None, max_lines=None):
    """한 줄을 표의 한 행으로 → 페이지를 넘어가도 자연스럽게 나뉜다."""
    lines = text.expandtabs(4).split("\n")
    if max_lines and len(lines) > max_lines:
        lines = lines[:max_lines] + [f"... (이하 {len(lines) - max_lines}줄 생략)"]
    avail = TEXT_W - 14
    cols = max([disp_width(l) for l in lines] + [1])
    size = min(8.2, avail / (cols * 0.5))
    size = max(size, 6.0)
    max_cols = int(avail / (size * 0.5))
    rows = []
    for l in lines:
        while disp_width(l) > max_cols:                       # 그래도 길면 줄바꿈
            cut, w = 0, 0
            for i, c in enumerate(l):
                w += 2 if unicodedata.east_asian_width(c) in "WF" else 1
                if w > max_cols:
                    cut = i
                    break
            rows.append(l[:cut])
            l = "  " + l[cut:]
        rows.append(l)
    st = ParagraphStyle("c", fontName="Mono", fontSize=size, leading=size * 1.32)
    data = [[Paragraph(escape(r).replace(" ", "&nbsp;") or "&nbsp;", st)] for r in rows]
    if label:
        data.insert(0, [Paragraph(label, S["label"])])
    t = Table(data, colWidths=[TEXT_W], splitByRow=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("LINEBEFORE", (0, 0), (0, -1), 2.2, border),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, 0), 4),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 4),
    ]))
    return t


def example_flow(block, with_output=True, kind="예제"):
    head = Table([[Paragraph(f"{kind} {block.id}&nbsp;&nbsp;∙&nbsp;&nbsp;{inline(block.title)}",
                             S["extitle"])]], colWidths=[TEXT_W])
    head.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), BLUE),
                              ("LEFTPADDING", (0, 0), (-1, -1), 8),
                              ("TOPPADDING", (0, 0), (-1, -1), 3),
                              ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    code = code_table(block.sql, CODE_BG, BLUE)
    flow = [CondPageBreak(60 * mm), KeepTogether([head, code]) if block.sql.count("\n") < 30 else head]
    if block.sql.count("\n") >= 30:
        flow.append(code)
    if with_output and block.output.strip():
        flow += [Spacer(1, 2), code_table(block.output, OUT_BG, colors.HexColor("#b8a94a"),
                                          label="▶ 실행 결과", max_lines=60)]
    flow.append(Spacer(1, 9))
    return flow


def callout(kind, title, lines):
    name, bg, edge = BOX[kind]
    inner = [Paragraph(f'<font color="{edge.hexval().replace("0x", "#")}">■ {name}</font>'
                       + (f"&nbsp;&nbsp;{inline(title)}" if title else ""), S["boxtitle"])]
    for l in lines:
        if l.strip().startswith("- "):
            inner.append(Paragraph(inline(l.strip()[2:]), S["boxbody"], bulletText="•"))
        elif l.strip():
            inner.append(Paragraph(inline(l), S["boxbody"]))
    t = Table([[inner]], colWidths=[TEXT_W])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), bg),
                           ("LINEBEFORE", (0, 0), (0, -1), 3, edge),
                           ("LEFTPADDING", (0, 0), (-1, -1), 10),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                           ("TOPPADDING", (0, 0), (-1, -1), 6),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    return [Spacer(1, 3), t, Spacer(1, 7)]


def md_table(rows):
    rows = [[c.strip().replace("\x00", "|") for c in r.replace("\\|", "\x00").strip().strip("|").split("|")]
            for r in rows]                                       # \| 는 칸 구분이 아닌 글자 |
    rows = [r for r in rows if not all(re.fullmatch(r":?-{2,}:?", c) for c in r)]
    ncol = len(rows[0])
    widths = [max(disp_width(re.sub(r"[`*]", "", r[i])) if i < len(r) else 0 for r in rows) for i in range(ncol)]
    head = [disp_width(re.sub(r"[`*]", "", c)) for c in rows[0]]
    widths = [min(max(w, h + 2, 5), 60) for w, h in zip(widths, head)]
    total = sum(widths)
    colw = [TEXT_W * w / total for w in widths]
    data = [[Paragraph(inline(c), S["cellh"] if i == 0 else S["cell"]) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=colw, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT]),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c9d3df")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return [Spacer(1, 2), t, Spacer(1, 8)]


class ChapterBanner(Flowable):
    """장 제목 띠 + 목차/북마크 등록."""

    def __init__(self, text):
        super().__init__()
        self.text = text
        self.para = Paragraph(inline(text), S["h1"])

    def wrap(self, aw, ah):
        self.para.wrap(aw - 24, ah)
        self.height = self.para.height + 26
        return aw, self.height

    def draw(self):
        c = self.canv
        c.setFillColor(NAVY)
        c.roundRect(0, 0, TEXT_W, self.height, 4, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#f0a500"))
        c.rect(0, 0, 6, self.height, fill=1, stroke=0)
        self.para.drawOn(c, 16, 12)


# ---------------------------------------------------------------- 문서 템플릿
class GuideDoc(BaseDocTemplate):
    def __init__(self, path):
        super().__init__(str(path), pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN,
                         topMargin=MARGIN + 6, bottomMargin=MARGIN, title=f"{TITLE} 강사용 교안",
                         author=INSTRUCTOR, subject="PostgreSQL 기초부터 심화까지")
        frame = Frame(MARGIN, MARGIN, TEXT_W, PAGE_H - 2 * MARGIN - 6, id="f")
        self.addPageTemplates([PageTemplate("cover", [frame], onPage=self.cover),
                               PageTemplate("body", [frame], onPageEnd=self.decorate)])
        self.chapter = ""

    def beforeDocument(self):
        self.chapter = ""

    def afterFlowable(self, f):
        if isinstance(f, ChapterBanner):
            self.chapter = re.sub(r"<[^>]+>", "", f.text)
            key = f"ch{self.page}{id(f)}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(self.chapter, key, level=0)
            self.notify("TOCEntry", (0, escape(self.chapter), self.page, key))
        elif isinstance(f, Paragraph) and f.style.name == "h2":
            text = f.getPlainText()
            key = f"h2{self.page}{id(f)}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=1)
            self.notify("TOCEntry", (1, escape(text), self.page, key))

    def decorate(self, c, doc):
        c.saveState()
        c.setFont("Body", 7.5)
        c.setFillColor(GREY)
        c.drawString(MARGIN, PAGE_H - MARGIN + 2, self.chapter)
        c.drawRightString(PAGE_W - MARGIN, PAGE_H - MARGIN + 2, f"{TITLE} ∙ 강사용 교안")
        c.setStrokeColor(colors.HexColor("#d1d9e3"))
        c.setLineWidth(0.5)
        c.line(MARGIN, PAGE_H - MARGIN - 1, PAGE_W - MARGIN, PAGE_H - MARGIN - 1)
        c.line(MARGIN, MARGIN - 7, PAGE_W - MARGIN, MARGIN - 7)
        c.drawString(MARGIN, MARGIN - 16, f"강사 {INSTRUCTOR}")
        c.drawCentredString(PAGE_W / 2, MARGIN - 16, str(doc.page))
        c.drawRightString(PAGE_W - MARGIN, MARGIN - 16, REPO)
        c.restoreState()

    def cover(self, c, doc):
        c.saveState()
        c.setFillColor(NAVY)
        c.rect(0, PAGE_H * 0.42, PAGE_W, PAGE_H * 0.58, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#f0a500"))
        c.rect(0, PAGE_H * 0.42 - 6, PAGE_W, 6, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#f0a500"))
        c.roundRect(MARGIN + 4, PAGE_H - 70 * mm, 34 * mm, 9 * mm, 3, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("BodyB", 11)
        c.drawCentredString(MARGIN + 4 + 17 * mm, PAGE_H - 70 * mm + 3 * mm, "강사용 교안")
        c.setFont("BodyB", 34)
        c.drawString(MARGIN + 4, PAGE_H - 95 * mm, "PostgreSQL")
        c.setFont("BodyB", 26)
        c.drawString(MARGIN + 4, PAGE_H - 110 * mm, "데이터베이스 기초부터 심화까지")
        c.setFont("Body", 12)
        c.setFillColor(colors.HexColor("#d6e2f0"))
        c.drawString(MARGIN + 4, PAGE_H - 124 * mm,
                     "SQL 기초 · JOIN · 윈도우 함수 · 인덱스 · 트랜잭션 · PL/pgSQL · JSONB · 운영 · Python 연동")
        c.setFillColor(NAVY)
        c.setFont("BodyB", 15)
        c.drawString(MARGIN + 4, 70 * mm, f"강사  {INSTRUCTOR}")
        c.setFont("Body", 10.5)
        c.setFillColor(colors.HexColor("#374151"))
        c.drawString(MARGIN + 4, 60 * mm, f"작성일  {date.today():%Y.%m.%d}")
        c.drawString(MARGIN + 4, 52 * mm, "실습 환경  PostgreSQL 18 (17 이상 권장) · psql · pgAdmin 4 / DBeaver")
        c.drawString(MARGIN + 4, 44 * mm, f"예제 저장소  https://{REPO}")
        c.setFont("Body", 8.5)
        c.setFillColor(GREY)
        c.drawString(MARGIN + 4, 28 * mm,
                     "이 교안의 모든 '실행 결과'는 저장소의 예제 SQL 을 PostgreSQL 18.6 에서 실제로 실행해 자동으로 넣은 것입니다.")
        c.restoreState()


# ---------------------------------------------------------------- 원고 → 흐름
class Builder:
    def __init__(self):
        self.blocks = {}
        self.sol_order = []
        self.py_out = {}

    def load_examples(self):
        for f in sorted((ROOT / "examples").glob("*.sql")):
            print("  실행:", f.name, flush=True)
            for b in runner.run(f):
                self.blocks[b.id] = b
            bad = runner.problems(self.blocks.values())
            if bad:
                raise SystemExit(f"예상하지 못한 오류: {[b.id for b in bad]}")
        for f in sorted((ROOT / "solutions").glob("*.sql")):
            print("  실행:", f.name, flush=True)
            for b in runner.run(f):
                self.blocks[b.id] = b
                self.sol_order.append(b.id)
        bad = runner.problems(self.blocks.values())
        if bad:
            raise SystemExit(f"예상하지 못한 오류: {[b.id for b in bad]}")

    def run_py(self, rel):
        if rel not in self.py_out:
            runner.reset_db()
            env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
            env.setdefault("DATABASE_URL", "postgresql://{u}@{h}:{p}/shop".format(
                u=os.environ.get("PGUSER", "postgres"), h=os.environ.get("PGHOST", "localhost"),
                p=os.environ.get("PGPORT", "5432")))
            p = subprocess.run([sys.executable, Path(rel).name], cwd=ROOT / Path(rel).parent,
                               capture_output=True, env=env)
            out = (p.stdout + p.stderr).decode("utf-8", "replace").replace("\r\n", "\n").rstrip()
            if p.returncode:
                raise SystemExit(f"{rel} 실행 실패\n{out}")
            self.py_out[rel] = out
        return self.py_out[rel]

    def parse(self, text):
        flow = []
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i]
            s = line.strip()
            if not s:
                i += 1
                continue
            if s.startswith("# "):
                flow += [NextPageTemplate("body"), PageBreak(), ChapterBanner(s[2:]), Spacer(1, 10)]
            elif s.startswith("## "):
                flow += [CondPageBreak(35 * mm), Paragraph(inline(s[3:]), S["h2"])]
            elif s.startswith("### "):
                flow += [CondPageBreak(25 * mm), Paragraph(inline(s[4:]), S["h3"])]
            elif s.startswith("@@ex ") or s.startswith("@@code "):
                for bid in s.split()[1:]:
                    flow += example_flow(self.blocks[bid], with_output=s.startswith("@@ex"))
            elif s.startswith("@@py "):
                rel = s.split()[1]
                src = (ROOT / rel).read_text(encoding="utf-8").rstrip()
                b = runner.Block(rel, "파이썬 실행 예제", src)
                b.output = self.run_py(rel)
                flow += example_flow(b, kind="")
            elif s.startswith("@@q "):
                rows = [[Paragraph("<b>번호</b>", S["cellh"]), Paragraph("<b>문제</b>", S["cellh"])]]
                for bid in s.split()[1:]:
                    b = self.blocks[bid]
                    rows.append([Paragraph(bid, S["cell"]),
                                 Paragraph(inline(b.title.replace(" [error]", "")), S["cell"])])
                t = Table(rows, colWidths=[18 * mm, TEXT_W - 18 * mm], repeatRows=1)
                t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#3c8d2f")),
                                       ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f0f7ee")]),
                                       ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c8dcc2")),
                                       ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]))
                flow += [t, Paragraph("정답과 실행 결과는 <b>부록 A</b>, 문제지 파일은 <font name='Mono'>exercises/</font> 폴더에 있습니다.", S["small"]), Spacer(1, 6)]
            elif s == "@@answers":
                cur = None
                for bid in self.sol_order:
                    ch = bid.split("-")[0]
                    if ch != cur:
                        cur = ch
                        flow += [CondPageBreak(40 * mm), Paragraph(f"{ch}장 실습 문제 정답", S["h3"])]
                    flow += example_flow(self.blocks[bid], kind="문제")
            elif s.startswith("@@image "):
                _, path, *w = s.split()
                width = float(w[0]) * mm if w else TEXT_W
                img = Image(str(ROOT / path))
                img.drawHeight = width * img.imageHeight / img.imageWidth
                img.drawWidth = width
                flow += [img, Spacer(1, 6)]
            elif s == "@@pagebreak":
                flow.append(PageBreak())
            elif s == "@@toc":
                toc = TableOfContents()
                toc.levelStyles = [S["toc1"], S["toc2"]]
                toc.dotsMinLevel = 0
                flow += [toc]
            elif s.startswith("> [!"):
                m = re.match(r"> \[!(\w+)\]\s*(.*)", s)
                body = []
                i += 1
                while i < len(lines) and lines[i].startswith(">"):
                    body.append(lines[i][1:].strip())
                    i += 1
                flow += callout(m.group(1), m.group(2), body)
                continue
            elif s.startswith("```"):
                buf = []
                i += 1
                while not lines[i].strip().startswith("```"):
                    buf.append(lines[i])
                    i += 1
                flow += [code_table("\n".join(buf), CODE_BG, GREY), Spacer(1, 8)]
            elif s.startswith("|"):
                buf = []
                while i < len(lines) and lines[i].strip().startswith("|"):
                    buf.append(lines[i])
                    i += 1
                flow += md_table(buf)
                continue
            elif re.match(r"^(\s*)- ", line):
                lvl = "bullet2" if line.startswith("  ") else "bullet"
                flow.append(Paragraph(inline(s[2:]), S[lvl], bulletText="•" if lvl == "bullet" else "–"))
            elif re.match(r"^\d+\. ", s):
                n, rest = s.split(". ", 1)
                flow.append(Paragraph(inline(rest), S["bullet"], bulletText=f"{n}."))
            else:
                para = [s]
                while (i + 1 < len(lines) and lines[i + 1].strip()
                       and not re.match(r"^(#|@@|>|```|\||\s*- |\d+\. )", lines[i + 1].strip())):
                    i += 1
                    para.append(lines[i].strip())
                flow.append(Paragraph(inline(" ".join(para)), S["body"]))
            i += 1
        return flow


def make_erd():
    """shop 스키마 ERD 그림 (docs/images/erd.png)."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import FancyBboxPatch
    plt.rcParams["font.family"] = "Malgun Gothic"
    W, RH, TOP, BOT = 3.0, 0.34, 8.0, 4.1
    tables = {
        "departments": (0.9, TOP, ["PK dept_id", "name", "location"]),
        "customers": (4.7, TOP, ["PK customer_id", "name", "email", "phone", "city", "grade",
                                 "birth_date", "joined_at"]),
        "products": (8.5, TOP, ["PK product_id", "FK category_id", "name", "price", "stock",
                                "is_active", "attrs (jsonb)", "created_at"]),
        "categories": (12.3, TOP, ["PK category_id", "name", "FK parent_id"]),
        "employees": (0.9, BOT, ["PK emp_id", "name", "FK dept_id", "FK manager_id", "job_title",
                                 "salary", "hire_date", "email"]),
        "orders": (4.7, BOT, ["PK order_id", "FK customer_id", "FK emp_id", "order_date", "status",
                              "ship_city"]),
        "order_items": (8.5, BOT, ["PK,FK order_id", "PK,FK product_id", "quantity", "unit_price"]),
        "reviews": (12.3, BOT, ["PK review_id", "FK product_id", "FK customer_id", "rating",
                                "content", "created_at"]),
    }
    fig, ax = plt.subplots(figsize=(15.6, 8.6))
    ax.set_xlim(0, 16.2)
    ax.set_ylim(0.5, 9.0)
    ax.axis("off")
    for name, (x, top, cols) in tables.items():
        h = RH * (len(cols) + 1)
        ax.add_patch(FancyBboxPatch((x, top - h), W, h, boxstyle="round,pad=0.02",
                                    fc="white", ec="#1f3a5f", lw=1.4, zorder=2))
        ax.add_patch(FancyBboxPatch((x, top - RH), W, RH, boxstyle="round,pad=0.02",
                                    fc="#1f3a5f", ec="#1f3a5f", zorder=3))
        ax.text(x + W / 2, top - RH / 2, name, ha="center", va="center", color="white",
                fontsize=12, fontweight="bold", zorder=4)
        for k, col in enumerate(cols):
            color = "#b5245e" if col.startswith("PK") else ("#336791" if col.startswith("FK") else "#222")
            ax.text(x + 0.12, top - RH * (k + 1.5), col, va="center", fontsize=10.5, color=color, zorder=4)

    def y(t, row):
        return tables[t][1] - RH * (row + 1.5)

    def bottom(t):
        return tables[t][1] - RH * (len(tables[t][2]) + 1)

    def x(t, side):
        return tables[t][0] + {"l": 0, "r": W, "m": W / 2}[side]

    arrow = dict(arrowstyle="-|>", color="#e8890c", lw=1.7, shrinkA=0, shrinkB=0)

    def path(points, label=None, at=0, dx=0.08, dy=0.1):
        xs, ys = zip(*points)
        ax.plot(xs[:-1] + (xs[-1],), ys, color="#e8890c", lw=1.7, zorder=1)
        ax.annotate("", xy=points[-1], xytext=points[-2], arrowprops=arrow, zorder=1)
        if label:
            ax.text(points[at][0] + dx, points[at][1] + dy, label, fontsize=9, color="#8a5a00")

    # 자식 FK → 부모 PK (화살표는 부모 쪽)
    path([(x("employees", "m"), BOT), (x("employees", "m"), bottom("departments"))], "N : 1", 0, 0.1, 0.25)
    path([(x("orders", "m") - 0.6, BOT), (x("orders", "m") - 0.6, bottom("customers"))], "N : 1", 0, 0.1, 0.25)
    path([(x("orders", "l"), y("orders", 2)), (x("employees", "r"), y("employees", 0))], "N : 1 (담당)", 1, 0.1, -0.45)
    path([(x("order_items", "l"), y("order_items", 0)), (x("orders", "r"), y("orders", 0))], "N : 1", 1, 0.15, 0.1)
    path([(x("order_items", "m"), BOT), (x("order_items", "m"), bottom("products"))], "N : 1", 0, 0.1, 0.25)
    path([(x("products", "r"), y("products", 1)), (x("categories", "l"), y("categories", 0))], "N : 1", 1, -0.75, 0.1)
    path([(x("reviews", "l") + 0.5, BOT), (x("reviews", "l") + 0.5, BOT + 0.35),
          (x("products", "r") - 0.4, BOT + 0.35), (x("products", "r") - 0.4, bottom("products"))],
         "N : 1", 0, 0.1, 0.05)
    path([(x("reviews", "r"), y("reviews", 2)), (15.75, y("reviews", 2)), (15.75, 8.65),
          (x("customers", "m"), 8.65), (x("customers", "m"), TOP)], "N : 1", 3, 0.1, 0.08)
    # 자기 참조
    path([(x("employees", "l"), y("employees", 3)), (0.45, y("employees", 3)),
          (0.45, y("employees", 0)), (x("employees", "l"), y("employees", 0))])
    ax.text(0.05, y("employees", 1.5), "상사", fontsize=9, color="#8a5a00", rotation=90, va="center")
    path([(x("categories", "r"), y("categories", 1)), (15.55, y("categories", 1)),
          (15.55, y("categories", 0)), (x("categories", "r"), y("categories", 0))])
    ax.text(12.3, bottom("categories") - 0.3, "parent_id → 상위 분류 (자기 참조)", fontsize=9, color="#8a5a00")
    ax.text(0.9, 0.75, "PK = 기본 키   FK = 외래 키   화살표: 자식(FK) → 부모(PK),  N : 1 = 부모 1행에 자식 여러 행",
            fontsize=10, color="#555")
    out = ROOT / "docs" / "images" / "erd.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=170, bbox_inches="tight")
    plt.close(fig)


def main():
    make_erd()
    b = Builder()
    print("예제 실행 중 ...")
    b.load_examples()
    story = [NextPageTemplate("cover"), Spacer(1, 1)]
    for md in sorted((ROOT / "docs" / "guide").glob("*.md")):
        print("  원고:", md.name, flush=True)
        story += b.parse(md.read_text(encoding="utf-8"))
    doc = GuideDoc(OUT)
    doc.multiBuild(story)
    print("완료:", OUT)


if __name__ == "__main__":
    main()
