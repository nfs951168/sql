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



----------------------------------------------------------------------------------------------------------------------------------------
--3. Get execution plans for particular query
----------------------------------------------------------------------------------------------------------------------------------------
SELECT TOP 10
    execution_count,
    total_elapsed_time / 1000 as totalDurationms,
    total_worker_time / 1000 as totalCPUms,
    total_logical_reads,
    total_physical_reads,
    t.text,
    sql_handle,
    plan_handle
FROM sys.dm_exec_query_stats s 
CROSS APPLY sys.dm_exec_sql_text(s.sql_handle) as t
where	t.text like '%select 1 as selected%'
ORDER BY total_elapsed_time DESC



----------------------------------------------------------------------------------------------------------------------------------------
--Index usage script
--  NumOfSeeks: indicates the number of times the index is used to find a specific row
--  NumOfScans: shows the number of times the leaf pages of the index are scanned
--  NumOfLookups: indicates the number of times a Clustered index is used by the Non-clustered index to fetch the full row 
--  NumOfUpdates: shows the number of times the index data is modified

--Analyze results
--   All zero values mean that the table is not used, or the SQL Server service restarted recently.
--   An index with zero or small number of seeks, scans or lookups and large number of updates is a useless index and should be removed, after verifying with the system owner, as the main purpose of adding the index is speeding up the read operations.
--   An index that is scanned heavily with zero or small number of seeks means that the index is badly used and should be replaced with more optimal one.
--   An index with large number of Lookups means that we need to optimize the index by adding the frequently looked up columns to the existing index non-key columns using the INCLUDE clause.
--   A table with a very large number of Scans indicates that SELECT * queries are heavily used, retrieving more columns than what is required, or the index statistics should be updated.
--   A Clustered index with large number of Scans means that a new Non-clustered index should be created to cover a non-covered query.
--   Dates with NULL values mean that this action has not occurred yet.
--   Large scans are OK in small tables.
--   Your index is not here, then no action is performed on that index yet.
----------------------------------------------------------------------------------------------------------------------------------------
SELECT OBJECT_NAME(IX.OBJECT_ID) Table_Name
	   ,IX.name AS Index_Name
	   ,IX.type_desc Index_Type
	   ,SUM(PS.[used_page_count]) * 8 IndexSizeKB
	   ,IXUS.user_seeks AS NumOfSeeks
	   ,IXUS.user_scans AS NumOfScans
	   ,IXUS.user_lookups AS NumOfLookups
	   ,IXUS.user_updates AS NumOfUpdates
	   ,IXUS.last_user_seek AS LastSeek
	   ,IXUS.last_user_scan AS LastScan
	   ,IXUS.last_user_lookup AS LastLookup
	   ,IXUS.last_user_update AS LastUpdate
FROM sys.indexes IX
INNER JOIN sys.dm_db_index_usage_stats IXUS ON IXUS.index_id = IX.index_id AND IXUS.OBJECT_ID = IX.OBJECT_ID
INNER JOIN sys.dm_db_partition_stats PS on PS.object_id=IX.object_id
WHERE OBJECTPROPERTY(IX.OBJECT_ID,'IsUserTable') = 1
GROUP BY OBJECT_NAME(IX.OBJECT_ID) ,IX.name ,IX.type_desc ,IXUS.user_seeks ,IXUS.user_scans ,IXUS.user_lookups,IXUS.user_updates ,IXUS.last_user_seek ,IXUS.last_user_scan ,IXUS.last_user_lookup ,IXUS.last_user_update
order by 1 asc


----------------------------------------------------------------------------------------------------------------------------------------
-- Index physical stats to be used with previous script
--  IndexSize
--   NumOfInserts
--   NumOfUpdates
--   NumOfDeletes
----------------------------------------------------------------------------------------------------------------------------------------

SELECT OBJECT_NAME(IXOS.OBJECT_ID)  Table_Name 
       ,IX.name  Index_Name
	   ,IX.type_desc Index_Type
	   ,SUM(PS.[used_page_count]) * 8 IndexSizeKB
       ,IXOS.LEAF_INSERT_COUNT NumOfInserts
       ,IXOS.LEAF_UPDATE_COUNT NumOfupdates
       ,IXOS.LEAF_DELETE_COUNT NumOfDeletes
	   
FROM   SYS.DM_DB_INDEX_OPERATIONAL_STATS (NULL,NULL,NULL,NULL ) IXOS 
INNER JOIN SYS.INDEXES AS IX ON IX.OBJECT_ID = IXOS.OBJECT_ID AND IX.INDEX_ID =    IXOS.INDEX_ID 
	INNER JOIN sys.dm_db_partition_stats PS on PS.object_id=IX.object_id
WHERE  OBJECTPROPERTY(IX.[OBJECT_ID],'IsUserTable') = 1
GROUP BY OBJECT_NAME(IXOS.OBJECT_ID), IX.name, IX.type_desc,IXOS.LEAF_INSERT_COUNT, IXOS.LEAF_UPDATE_COUNT,IXOS.LEAF_DELETE_COUNT
