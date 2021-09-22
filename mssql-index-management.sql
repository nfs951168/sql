----------------------------------------------------------------------------------------------------------------------------------------
--1. Find missing Indexes
----------------------------------------------------------------------------------------------------------------------------------------
SELECT   DISTINCT CONVERT(DECIMAL(18, 2) , user_seeks * avg_total_user_cost * ( avg_user_impact * 0.01 )) AS [index_advantage] ,
         migs.last_user_seek ,
         mid.[statement] AS [Database.Schema.Table] ,
         mid.equality_columns ,
         mid.inequality_columns ,
         mid.included_columns ,
         migs.unique_compiles ,
         migs.user_seeks ,
         migs.avg_total_user_cost ,
         migs.avg_user_impact ,
         OBJECT_NAME(mid.[object_id]) AS [Table Name] ,
         p.rows AS [Table Rows]
FROM     sys.dm_db_missing_index_group_stats AS migs WITH ( NOLOCK )
         INNER JOIN sys.dm_db_missing_index_groups AS mig WITH ( NOLOCK ) ON migs.group_handle = mig.index_group_handle
         INNER JOIN sys.dm_db_missing_index_details AS mid WITH ( NOLOCK ) ON mig.index_handle = mid.index_handle
         INNER JOIN sys.partitions AS p WITH ( NOLOCK ) ON p.[object_id] = mid.[object_id]
WHERE    mid.database_id = DB_ID()
ORDER BY index_advantage DESC
OPTION ( RECOMPILE );



----------------------------------------------------------------------------------------------------------------------------------------
--2. Index fragmentation
----------------------------------------------------------------------------------------------------------------------------------------
SELECT	S.name as 'Schema',
		T.name as 'Table',
		I.name as 'Index',
		DDIPS.avg_fragmentation_in_percent,
		DDIPS.page_count
FROM	sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS 
				INNER JOIN sys.tables T on (T.object_id = DDIPS.object_id)
				INNER JOIN sys.schemas S on (T.schema_id = S.schema_id)
				INNER JOIN sys.indexes I ON (I.object_id = DDIPS.object_id AND DDIPS.index_id = I.index_id)
WHERE	DDIPS.database_id = DB_ID()
and		I.name is not null
AND		DDIPS.avg_fragmentation_in_percent > 0
and		t.name like '%ossys_espace%'
ORDER BY DDIPS.avg_fragmentation_in_percent desc
