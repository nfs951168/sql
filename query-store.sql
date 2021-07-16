------------------------------------------------------------------------------------------------------------------------------------
--How to get a specific query from query store
------------------------------------------------------------------------------------------------------------------------------------

--1. Get que query_id
SELECT 
    qsq.query_id,
    qsq.last_execution_time,
    qsqt.query_sql_text
FROM sys.query_store_query qsq
    INNER JOIN sys.query_store_query_text qsqt
        ON qsq.query_text_id = qsqt.query_text_id
WHERE
    qsqt.query_sql_text LIKE '%your query text%';
    
    
    
    --2. search in query store management console
