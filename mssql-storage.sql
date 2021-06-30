--------------------------------------------------------------------------------------------------------------------------------------------------------
--Gives information about storage file fize and freespace
--------------------------------------------------------------------------------------------------------------------------------------------------------

;WITH src AS
(
  SELECT FG          = fg.name, 
         FileID      = f.file_id,
         LogicalName = f.name,
         [Path]      = f.physical_name, 
         FileSizeMB  = f.size/128.0, 
         UsedSpaceMB = CONVERT(bigint, FILEPROPERTY(f.[name], 'SpaceUsed'))/128.0, 
         GrowthMB    = CASE f.is_percent_growth WHEN 1 THEN NULL ELSE f.growth/128.0 END,
         MaxSizeMB   = NULLIF(f.max_size, -1)/128.0,
         DriveSizeMB = vs.total_bytes/1048576.0,
         DriveFreeMB = vs.available_bytes/1048576.0
  FROM sys.database_files AS f
  INNER JOIN sys.filegroups AS fg
        ON f.data_space_id = fg.data_space_id
  CROSS APPLY sys.dm_os_volume_stats(DB_ID(), f.file_id) AS vs
)
SELECT [Filegroup] = FG, FileID, LogicalName, [Path],
  FileSizeMB  = CONVERT(decimal(18,2), FileSizeMB),
  FreeSpaceMB = CONVERT(decimal(18,2), FileSizeMB-UsedSpaceMB),
  [%]         = CONVERT(decimal(5,2), 100.0*(FileSizeMB-UsedSpaceMB)/FileSizeMB),
  GrowthMB    = COALESCE(RTRIM(CONVERT(decimal(18,2), GrowthMB)), '% warning!'),
  MaxSizeMB   = CONVERT(decimal(18,2), MaxSizeMB),
  DriveSizeMB = CONVERT(bigint, DriveSizeMB),
  DriveFreeMB = CONVERT(bigint, DriveFreeMB),
  [%]         = CONVERT(decimal(5,2), 100.0*(DriveFreeMB)/DriveSizeMB)
FROM src
ORDER BY FG, LogicalName;



--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Returns size and rows of each user table in database

--sys.tables: list each user table in current SQL Server Database
--sys.indexes: Contains a row per index or heap of a tabular object, such as a table, view, or table-valued function
--sys.partitions: has the partitions of all tables and the number of rows
--sys_allocation_units: Number of pages of each allocation unit
--sys.schemas: identifies the schema of each table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

select	T.Name as [table-name],
		s.name as [schema],
		p.rows,
		SUM(au.total_pages) * 8 [total-space-kb],
		CAST(ROUND(((SUM(au.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS [total-space-mb],
		SUM(au.used_pages) * 8 AS [used-space-kb], 
		CAST(ROUND(((SUM(au.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS [used-space-mb], 
		(SUM(au.total_pages) - SUM(au.used_pages)) * 8 AS [unused-space-kb],
		 CAST(ROUND(((SUM(au.total_pages) - SUM(au.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS [unused-space-mb] 
from	sys.tables T	inner join sys.indexes I on (i.object_id = t.object_id)
						inner join sys.partitions P on (p.object_id = i.object_id and p.index_id = p.index_id)
						inner join sys.allocation_units au on (au.container_id = p.partition_id)
						left join sys.schemas s on (s.schema_id = t.schema_id)
group by t.name, s.name, p.rows
