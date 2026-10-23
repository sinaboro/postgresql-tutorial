-- =====================================================================
-- 16장. PostgreSQL 다운 기능 - JSONB, 배열, 전문 검색
-- =====================================================================
SET client_min_messages = warning;
DROP TABLE IF EXISTS events, articles;
RESET client_min_messages;

-- @ex 16-01 JSONB 컬럼 조회 - 키로 값 꺼내기 (-> 는 JSON, ->> 는 텍스트)
SELECT name,
       attrs -> 'brand'   AS brand_json,
       attrs ->> 'brand'  AS brand_text,
       attrs ->> 'color'  AS color
FROM products
WHERE product_id IN (1, 4, 6, 18);

-- @ex 16-02 중첩 값과 배열 원소 꺼내기 (#>>, -> 인덱스)
SELECT name,
       attrs -> 'sizes'           AS sizes,
       attrs -> 'sizes' ->> 0     AS 첫사이즈,
       attrs #>> '{sizes,1}'      AS 두번째사이즈,
       jsonb_array_length(attrs -> 'sizes') AS 사이즈수
FROM products
WHERE attrs ? 'sizes';                       -- ? : 키가 존재하는가

-- @ex 16-03 JSONB 로 검색 - 포함 연산자 @> 와 형변환
SELECT name, attrs ->> 'brand' AS brand
FROM products
WHERE attrs @> '{"brand": "한빛"}';
SELECT name, (attrs ->> 'ram_gb')::int AS ram
FROM products
WHERE (attrs ->> 'ram_gb')::int >= 16;

-- @ex 16-04 JSONB 수정 - 키 추가/변경(||, jsonb_set), 삭제(-)
UPDATE products
SET attrs = attrs || '{"warranty_years": 2}'
WHERE product_id = 1;
UPDATE products
SET attrs = jsonb_set(attrs, '{color}', '"space gray"')
WHERE product_id = 1;
UPDATE products SET attrs = attrs - 'weight_kg' WHERE product_id = 1;
SELECT attrs FROM products WHERE product_id = 1;

-- @ex 16-05 JSONB 를 행으로 펼치기 - jsonb_each_text
SELECT p.name, kv.key, kv.value
FROM products p, jsonb_each_text(p.attrs) AS kv
WHERE p.product_id = 3;

-- @ex 16-06 테이블 → JSON 만들기 (API 응답 형태)
SELECT jsonb_build_object(
           'customer', c.name,
           'grade',    c.grade,
           'orders',   (SELECT jsonb_agg(jsonb_build_object('id', o.order_id,
                                                            'date', o.order_date::date)
                                         ORDER BY o.order_id)
                        FROM orders o
                        WHERE o.customer_id = c.customer_id AND o.order_id < 20)
       ) AS result
FROM customers c
WHERE c.customer_id = 10;

-- @ex 16-07 JSONB 인덱스 - GIN
CREATE TABLE events (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payload JSONB NOT NULL
);
INSERT INTO events (payload)
SELECT jsonb_build_object('type', (ARRAY['click','view','buy'])[1 + g % 3],
                          'user', g % 1000,
                          'page', '/p/' || (g % 50))
FROM generate_series(1, 30000) g;
CREATE INDEX idx_events_payload ON events USING GIN (payload);
ANALYZE events;
EXPLAIN (COSTS OFF)
SELECT count(*) FROM events WHERE payload @> '{"type": "buy", "user": 7}';

-- @ex 16-08 배열 타입 - 생성, 원소 접근, 포함 검사
ALTER TABLE products ADD COLUMN tags TEXT[] DEFAULT '{}';
UPDATE products SET tags = ARRAY['신상품', '무료배송'] WHERE product_id IN (1, 4);
UPDATE products SET tags = ARRAY['무료배송']          WHERE product_id IN (6, 7, 8);
UPDATE products SET tags = ARRAY['할인', '무료배송']  WHERE product_id = 12;
SELECT name, tags, tags[1] AS 첫태그, cardinality(tags) AS 태그수
FROM products WHERE cardinality(tags) > 0 ORDER BY product_id;

-- @ex 16-09 배열 검색 - ANY, @>(모두 포함), &&(하나라도 겹침)
SELECT name FROM products WHERE '할인' = ANY (tags);
SELECT name FROM products WHERE tags @> ARRAY['신상품', '무료배송'];
SELECT count(*) AS 겹침 FROM products WHERE tags && ARRAY['할인', '신상품'];

-- @ex 16-10 unnest - 배열을 행으로 펼쳐서 집계
SELECT tag, count(*) AS 상품수
FROM products, unnest(tags) AS tag
GROUP BY tag
ORDER BY 상품수 DESC, tag;

-- @ex 16-11 전문 검색(Full Text Search) 기초 - tsvector, tsquery
SELECT to_tsvector('simple', '배송이 빠르고 품질 최고') AS tsvector;
SELECT to_tsvector('simple', '배송이 빠르고 품질 최고') @@ to_tsquery('simple', '품질') AS 일치,
       to_tsvector('simple', '배송이 빠르고 품질 최고') @@ to_tsquery('simple', '품질 & 가격') AS 둘다;

-- @ex 16-12 리뷰 검색 + 순위 (영문 설정은 어간 추출도 지원)
CREATE TABLE articles (id INT PRIMARY KEY, body TEXT, tsv TSVECTOR
    GENERATED ALWAYS AS (to_tsvector('english', body)) STORED);
INSERT INTO articles (id, body) VALUES
    (1, 'PostgreSQL indexes make queries faster'),
    (2, 'Indexing JSON documents with GIN'),
    (3, 'Window functions and running totals');
CREATE INDEX idx_articles_tsv ON articles USING GIN (tsv);
SELECT id, body, round(ts_rank(tsv, q)::numeric, 3) AS rank
FROM articles, to_tsquery('english', 'index') q
WHERE tsv @@ q
ORDER BY rank DESC;

-- @ex 16-13 [확장] pg_trgm - 한글 부분 검색(LIKE '%..%')을 인덱스로
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT similarity('노트북 거치대', '노트북') AS 유사도;
CREATE INDEX idx_reviews_content_trgm ON reviews USING GIN (content gin_trgm_ops);
SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT * FROM reviews WHERE content LIKE '%배송%';
RESET enable_seqscan;
SELECT review_id, rating, content FROM reviews WHERE content LIKE '%배송%' ORDER BY review_id LIMIT 4;
