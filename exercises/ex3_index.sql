-- Exercise 3 - Does the index make vector search faster? (slides 15-17)
-- Two tables with the same 100,000 vectors (synthetic numbers, only for measuring).
-- Only Workshop.BenchHNSW has an HNSW index. In the Management Portal use "Show Plan" instead of "Execute"
-- to see how a query will run. The timing is in the IRIS terminal (Workshop Guide, Exercise 3).

-- 1. Same rows in both tables
SELECT COUNT(*) AS exact_rows FROM Workshop.BenchExact;
SELECT COUNT(*) AS hnsw_rows FROM Workshop.BenchHNSW;

-- 2. How the index was created (already done for you; building it took ~100 s):
--    CREATE INDEX HNSWIdx ON TABLE Workshop.BenchHNSW (vec) AS HNSW(M=16, efConstruction=200, Distance='DotProduct')

-- 3. "Show Plan" for both queries. Which one reads "index map Workshop.BenchHNSW.HNSWIdx"?
SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, EMBEDDING('find my nearest neighbours', 'workshop-minilm')) AS score
FROM Workshop.BenchExact
ORDER BY score DESC;

SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, EMBEDDING('find my nearest neighbours', 'workshop-minilm')) AS score
FROM Workshop.BenchHNSW
ORDER BY score DESC;

-- 4. The index is used only for "the top k nearest": TOP + ORDER BY ... DESC. Show Plan without TOP - no index:
SELECT vec_id, VECTOR_DOT_PRODUCT(vec, EMBEDDING('find my nearest neighbours', 'workshop-minilm')) AS score
FROM Workshop.BenchHNSW
ORDER BY score DESC;
