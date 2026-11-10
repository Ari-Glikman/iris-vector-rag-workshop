-- Exercise 2, part B - Search the chunks with SQL (slides 9-14)
-- Do part A first (Workshop Guide): write ##class(Workshop.Exercise.Ex2).IngestAll() stores the handbook sections.
-- Run each statement in the Management Portal (System Explorer > SQL, namespace USER), one at a time.
-- Fill in the ____ blank. Completed version: solutions/ex2_semantic_search.sql

-- ===== What part A produced =============================================================================
-- The text, and a vector of 384 numbers that IRIS computed for it (the EMBEDDING column).
SELECT chunk_id, title, content, embedding FROM Workshop.SupportChunks;

-- ===== Search ===========================================================================================
-- EMBEDDING('question') turns the question into a vector with the column's model; VECTOR_DOT_PRODUCT scores every
-- chunk (Exercise 1); ORDER BY ... DESC puts the closest meaning first.
-- TODO 2: put a question into the blank, e.g.  What is the way to save vector data in a column?
SELECT TOP 3 chunk_id, title, VECTOR_DOT_PRODUCT(embedding, EMBEDDING('____')) AS score
FROM Workshop.SupportChunks
ORDER BY score DESC;

-- Change the question and run it again:
--   'Where can I keep my vectors inside the database?'          (a paraphrase)
--   'How long do we keep backups?'
--   'What is a good recipe for sourdough bread?'                (nothing in the handbooks - what comes back?)

-- TOP 3 always returns the 3 closest chunks, relevant or not. Keep only good matches with a minimum score:
SELECT TOP 3 chunk_id, title, VECTOR_DOT_PRODUCT(embedding, EMBEDDING('What is a good recipe for sourdough bread?')) AS score
FROM Workshop.SupportChunks
WHERE VECTOR_DOT_PRODUCT(embedding, EMBEDDING('What is a good recipe for sourdough bread?')) >= 0.3
ORDER BY score DESC;
