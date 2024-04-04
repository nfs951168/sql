-----------------------------------------------------------------------------------------------------
--Returns the most expensive queries in database - query execution statistics
-----------------------------------------------------------------------------------------------------
SELECT	TOP 10 qt.Text,
		qs.execution_count,
		qs.total_logical_reads, 
		qs.last_logical_reads,
		qs.total_logical_writes, 
		qs.last_logical_writes,
		qs.total_worker_time,
		qs.last_worker_time,
		qs.total_elapsed_time/1000000 total_elapsed_time_in_S,
		qs.last_elapsed_time/1000000 last_elapsed_time_in_S,
		qs.last_execution_time,
		qs.last_rows,
		qs.min_rows,
		qs.max_rows,
		qp.query_plan
FROM 	sys.dm_exec_query_stats qs 	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
					CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE	qs.creation_time >= '2024-04-04 00:00:00' -- all plans created after date
--ORDER BY qs.total_logical_reads DESC -- High Disk Reading query
ORDER BY qs.total_worker_time DESC -- High CPU query
--ORDER BY qs.total_elapsed_time DESC -- Long Running query


-- ----------------------------------------------------------------
-- Get current cached query plans
-- ----------------------------------------------------------------
SELECT 	db.name,
  	cp.objtype AS ObjectType,
  	OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
  	cp.usecounts AS ExecutionCount,
  	st.TEXT AS QueryText,
  	qp.query_plan AS QueryPlan
FROM 	sys.dm_exec_cached_plans AS cp
  	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
  	CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
  	INNER JOIN sys.sysdatabases db on st.dbid = db.dbid
where 	st.TEXT like '%%'
and 	db.name = ''
