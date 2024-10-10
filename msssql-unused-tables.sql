/*
 
Last instance restart date/time:
 
select sqlserver_start_time from sys.dm_os_sys_info with(nolock)
 
*/
 
declare @TableFilter varchar(100) = 'OSUSR%'
 
-- ------------------------------------------------------------------------
-- #TablesRowCount build
-- ------------------------------------------------------------------------
if object_id('tempdb..#TablesRowCount') is not null
    drop table #TablesRowCount
 
select 
    t.name as table_name,
    sum(p.row_count) as row_count
into #tablesrowcount
from sys.tables as t with(nolock) 
    join sys.indexes as i with(nolock) on t.object_id = i.object_id
    join sys.dm_db_partition_stats as p with(nolock) on i.object_id = p.object_id and i.index_id = p.index_id
where i.type in (0, 1)  -- 0 = heap, 1 = clustered
  and t.name like @TableFilter
group by t.name
order by t.name
 
-- ------------------------------------------------------------------------
-- #IndexUsage build
-- ------------------------------------------------------------------------
if object_id('tempdb..#IndexUsage') is not null
    drop table #IndexUsage
 
select object_name(s.[object_id]) as [table_name],
       i.[name] as [index_name],
       user_seeks,
       last_user_seek,
       user_scans,
       last_user_scan,
       user_lookups,
       last_user_lookup,
       user_updates,
       last_user_update
into #IndexUsage
from sys.dm_db_index_usage_stats as s with(nolock)
     inner join sys.indexes as i with(nolock) on i.[object_id] = s.[object_id] and i.index_id = s.index_id
where objectproperty(s.[object_id],'IsUserTable') = 1 
  and s.database_id = db_id()
  and object_name(s.[object_id]) like @TableFilter
order by object_name(s.[object_id])
 
-- ------------------------------------------------------------------------
-- #EspaceInfo build
-- ------------------------------------------------------------------------
if object_id('tempdb..#EspaceInfo') is not null
    drop table #EspaceInfo
 
select es.name [espace_name], e.name [entity_name], e.PHYSICAL_TABLE_NAME [table_name], es.IS_ACTIVE [is_espace_active]
into #EspaceInfo
from ossys_entity e with(nolock) inner join ossys_espace es with(nolock) on e.espace_id = es.id 
where e.ESPACE_ID is not null 
  and e.IS_ACTIVE = 1
  and e.PHYSICAL_TABLE_NAME LIKE @TableFilter
 
--select *
--from #EspaceInfo
 
-- ------------------------------------------------------------------------
-- Get the final result set
-- ------------------------------------------------------------------------
select coalesce(t.table_name, e.table_name) [Table Name],
       t.row_count [Row Count],
       max(i.last_user_seek) [Last User Seek], 
       max(i.last_user_scan) [Last User Scan], 
       max(i.last_user_lookup) [Last User Lookup], 
       max(i.last_user_update) [Last User Update],
       e.espace_name [Espace Name],
       e.entity_name [Entity Name],
       e.is_espace_active [Is Espace Active]
from #TablesRowCount t 
     full outer join #EspaceInfo e on t.table_name = e.table_name
     left outer join #IndexUsage i on t.table_name = i.table_name
group by coalesce(t.table_name, e.table_name), t.row_count, e.espace_name, e.entity_name, e.is_espace_active
order by coalesce(t.table_name, e.table_name)