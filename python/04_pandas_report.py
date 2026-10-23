"""19-04 조회 결과를 pandas DataFrame 으로 받아 분석하고 차트 저장"""
import pandas as pd

from db import connect

SQL = """
SELECT to_char(date_trunc('month', o.order_date), 'YYYY-MM') AS month,
       c.name AS category,
       sum(oi.quantity * oi.unit_price)::bigint AS sales
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories c   ON c.category_id = p.category_id
WHERE o.status <> 'CANCELLED' AND o.order_date >= %s
GROUP BY 1, 2
ORDER BY 1, 2
"""

with connect() as conn, conn.cursor() as cur:
    cur.execute(SQL, ("2026-01-01",))
    df = pd.DataFrame(cur.fetchall(), columns=[d.name for d in cur.description])

print(df.head(), "\n")

# 월 × 분류 피벗 (만원 단위)
pivot = df.pivot_table(index="month", columns="category", values="sales",
                       aggfunc="sum", fill_value=0) // 10000
print(pivot[["노트북", "스마트폰", "주변기기"]])

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib import font_manager
    installed = {f.name for f in font_manager.fontManager.ttflist}
    for font in ["Malgun Gothic", "AppleGothic", "NanumGothic"]:   # 한글 폰트 (Win/Mac/Linux)
        if font in installed:
            plt.rcParams["font.family"] = font
            break
    ax = pivot.sum(axis=1).plot(kind="bar", title="2026년 월별 매출(만원)", figsize=(7, 3.5))
    ax.set_xlabel("")
    plt.tight_layout()
    plt.savefig("monthly_sales.png", dpi=120)
    print("\n차트 저장: monthly_sales.png")
except ImportError:
    print("\n(matplotlib 이 없어 차트는 건너뜀)")
