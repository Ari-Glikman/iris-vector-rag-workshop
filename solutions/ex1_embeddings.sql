-- Exercise 1 - Embeddings in SQL (slides 3-11): step 1 (register the model) and step 4 (most similar sentences).
-- Steps 2 and 3 are in the IRIS terminal (Workshop Guide).
-- Run each statement in the Management Portal: System Explorer > SQL > namespace USER > Execute Query (one at a time).
-- This is the completed version.

-- ===== Step 1. Load an embedding model ==================================================================
-- You downloaded it in the IRIS terminal (write ##class(Workshop.Exercise.Ex1).LoadModel() -> 384).
-- Now tell SQL about it. %Embedding.Config is a list of "recipes": a name, the IRIS class that runs the model,
-- the model, and the vector length. This one runs the Hugging Face model you downloaded, inside IRIS.
INSERT INTO %Embedding.Config (Name, Configuration, EmbeddingClass, VectorLength, Description)
VALUES ('workshop-minilm',
        '{"modelName": "sentence-transformers/all-MiniLM-L6-v2", "hfCachePath": "/durable/hf-cache"}',
        '%Embedding.SentenceTransformers', 384,
        'all-MiniLM-L6-v2 from Hugging Face, runs inside IRIS');

SELECT Name, EmbeddingClass, VectorLength, Configuration FROM %Embedding.Config;

-- ===== Step 4. Which sentences are most similar? ========================================================
-- EMBEDDING(text, 'workshop-minilm') turns each sentence into a vector; VECTOR_DOT_PRODUCT compares two (step 3).
-- Before you run it: which pair will win? Every pair of the six sentences gets a score, best first.
WITH s (n, sentence) AS (
    SELECT 1, 'How do I store embeddings in a database table?'
    UNION ALL SELECT 2, 'What is the way to save vector data in a column?'
    UNION ALL SELECT 3, 'The cafeteria closes at three o''clock on Fridays.'
    UNION ALL SELECT 4, 'Where can I get lunch on a Friday afternoon?'
    UNION ALL SELECT 5, 'My password reset email never arrived.'
    UNION ALL SELECT 6, 'I did not receive the email to reset my password.')
SELECT a.n AS sentence_a, b.n AS sentence_b,
       VECTOR_DOT_PRODUCT(EMBEDDING(a.sentence, 'workshop-minilm'), EMBEDDING(b.sentence, 'workshop-minilm')) AS score,
       a.sentence AS text_a, b.sentence AS text_b
FROM s a, s b
WHERE a.n < b.n
ORDER BY score DESC;

-- ===== Step 5 (optional). A second model: OpenAI text-embedding-3-small (runs at OpenAI, not in IRIS) =======
-- Paste the workshop key (valid today only) instead of <WORKSHOP_OPENAI_KEY>. The key is stored in plain text
-- in this table, which is why we use a short-lived key. "workshop_ssl" is the HTTPS configuration built into the image.
INSERT INTO %Embedding.Config (Name, Configuration, EmbeddingClass, VectorLength, Description)
VALUES ('workshop-openai',
        '{"apiKey": "<WORKSHOP_OPENAI_KEY>", "sslConfig": "workshop_ssl", "modelName": "text-embedding-3-small"}',
        '%Embedding.OpenAI', 1536,
        'OpenAI text-embedding-3-small (hosted)');

-- Same sentences, other model: the text is sent to OpenAI, a 1,536-number vector comes back. Other scores, same winner?
SELECT VECTOR_DOT_PRODUCT(EMBEDDING('My password reset email never arrived.', 'workshop-openai'),
                          EMBEDDING('I did not receive the email to reset my password.', 'workshop-openai')) AS dot_5_6_openai,
       VECTOR_DOT_PRODUCT(EMBEDDING('How do I store embeddings in a database table?', 'workshop-openai'),
                          EMBEDDING('What is the way to save vector data in a column?', 'workshop-openai')) AS dot_1_2_openai;

-- Vectors from different models can never be compared. This fails on purpose:
SELECT VECTOR_DOT_PRODUCT(EMBEDDING('How do I store embeddings in a database table?', 'workshop-minilm'),
                          EMBEDDING('How do I store embeddings in a database table?', 'workshop-openai')) AS mixed_models;
