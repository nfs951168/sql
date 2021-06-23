Use OutsystemsDB;

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
