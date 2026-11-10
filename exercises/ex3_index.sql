-- Exercise 3 - Exact search vs HNSW (slides 15-17)
-- Two tables with the same 20,000 synthetic vectors (meaningless numbers, only for measuring).
-- Only Workshop.BenchHNSW has an HNSW index. In the Management Portal use "Show Plan" instead of "Execute"
-- to see how a query will run. The measurement (median, p95, recall) is the ObjectScript part: Workshop.Exercise.Ex3.

-- 1. Same rows in both tables
SELECT COUNT(*) AS exact_rows FROM Workshop.BenchExact;
SELECT COUNT(*) AS hnsw_rows FROM Workshop.BenchHNSW;

-- 2. How the index was created (already done for you; building it took ~11 s):
--    CREATE INDEX HNSWIdx ON TABLE Workshop.BenchHNSW (vec) AS HNSW(M=16, efConstruction=64, Distance='DotProduct')

-- 3. "Show Plan" for both queries. Which one reads "index map Workshop.BenchHNSW.HNSWIdx"?
SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, TO_VECTOR(EMBEDDING('find my nearest neighbours', 'workshop-minilm'), DOUBLE, 384)) AS score
FROM Workshop.BenchExact
ORDER BY score DESC;

SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, TO_VECTOR(EMBEDDING('find my nearest neighbours', 'workshop-minilm'), DOUBLE, 384)) AS score
FROM Workshop.BenchHNSW
ORDER BY score DESC;

-- 4. Now "Execute" both. Why are the times so similar? (Hint: most of the time is spent embedding the text.)

-- 5. Show Plan: does the index still get used ...
--    a) without TOP?
SELECT vec_id, VECTOR_DOT_PRODUCT(vec, TO_VECTOR(EMBEDDING('find my nearest neighbours', 'workshop-minilm'), DOUBLE, 384)) AS score
FROM Workshop.BenchHNSW
ORDER BY score DESC;
--    b) sorted ASC (worst first)?
SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, TO_VECTOR(EMBEDDING('find my nearest neighbours', 'workshop-minilm'), DOUBLE, 384)) AS score
FROM Workshop.BenchHNSW
ORDER BY score ASC;
--    c) with the query vector taken from a subquery instead of a constant?
SELECT TOP 10 vec_id, VECTOR_DOT_PRODUCT(vec, (SELECT q.vec FROM Workshop.BenchQueries q WHERE q.q_no = 10)) AS score
FROM Workshop.BenchHNSW
ORDER BY score DESC;

-- 6. Measure properly in the IRIS terminal:  do ##class(Workshop.Exercise.Ex3).Run()
--    50 seeded query vectors + 10 warm-up, only the database call is timed, both tables in alternating order.
--    It reports median, p95 and recall@10 (how many of the true 10 nearest neighbours the index found).
--    TODO 3 (timing) is in that class; recall is computed for you.
