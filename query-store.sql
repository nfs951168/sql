------------------------------------------------------------------------------------------------------------------------------------
--How to get a specific query from query store
------------------------------------------------------------------------------------------------------------------------------------

--1. Get que query_id
SELECT 
    qs.query_id,
    qs.last_execution_time,
	qs.avg_bind_cpu_time,
    qst.query_sql_text
FROM sys.query_store_query qs INNER JOIN sys.query_store_query_text qst ON (qs.query_text_id = qst.query_text_id)
WHERE	1 = 1
and		qs.last_execution_time >= '2022-03-18 12:00:00'
AND    qst.query_sql_text LIKE '%OSUSR_9PE_TIMESHEET%'
and		qst.query_sql_text like '%OSUSR_9PE_EXTRANETUSERS%'
and		qst.query_sql_text like '%BWSCONTRACTREFERENCE%'
order by qs.last_execution_time desc    
