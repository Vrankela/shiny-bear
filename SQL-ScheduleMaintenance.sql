/*

Set up schedule for SQL Server Maintenance Solution.

By Johan Kritzinger

Depends on maintenance solution by Ola Hallengren
https://ola.hallengren.com

*/


USE msdb ;
GO
-- creates schedules with logical names

EXEC sp_add_schedule
    @schedule_name = N'Daily105am' ,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010500 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'every30min' ,
    @freq_type = 4,
	@freq_interval = 4,
    @freq_subday_type = 4,
    @freq_subday_interval = 30,
    @active_start_time = 010000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'Daily12am' ,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 000000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySat11pm' ,
    @freq_type = 8,
    @freq_interval = 64,
    @freq_recurrence_factor=1,
    @active_start_time = 230000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySat6am' ,
    @freq_type = 8,
    @freq_interval = 64,
    @freq_recurrence_factor=1,
    @active_start_time = 060000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySat7am' ,
    @freq_type = 8,
    @freq_interval = 64,
    @freq_recurrence_factor=1,
    @active_start_time = 070000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklyMon3am' ,
    @freq_type = 8,
    @freq_interval = 2,
    @freq_recurrence_factor=1,
    @active_start_time = 030000 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySun1201' ,
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor=1,
    @active_start_time = 000100 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySun1202' ,
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor=1,
    @active_start_time = 000200 ;
GO

EXEC sp_add_schedule
    @schedule_name = N'WeeklySun1203' ,
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor=1,
    @active_start_time = 000300 ;
GO

--  Attach schedules to jobs
EXEC sp_attach_schedule
   @job_name = N'DatabaseBackup - USER_DATABASES - FULL',
   @schedule_name = N'Daily105am' ;
GO

EXEC sp_attach_schedule
   @job_name = N'DatabaseBackup - USER_DATABASES - LOG',
   @schedule_name = N'every30min' ;
GO

EXEC sp_attach_schedule
   @job_name = N'DatabaseBackup - SYSTEM_DATABASES - FULL',
   @schedule_name = N'Daily12am' ;
GO

EXEC sp_attach_schedule
   @job_name = N'CommandLog Cleanup',
   @schedule_name = N'WeeklySat11pm' ;
GO

EXEC sp_attach_schedule
   @job_name = N'DatabaseIntegrityCheck - SYSTEM_DATABASES',
   @schedule_name = N'WeeklySat6am' ;
GO

EXEC sp_attach_schedule
   @job_name = N'DatabaseIntegrityCheck - USER_DATABASES',
   @schedule_name = N'WeeklySat7am' ;
GO

EXEC sp_attach_schedule
   @job_name = N'IndexOptimize - USER_DATABASES',
   @schedule_name = N'WeeklyMon3am' ;
GO

EXEC sp_attach_schedule
   @job_name = N'Output File Cleanup',
   @schedule_name = N'WeeklySun1201' ;
GO

EXEC sp_attach_schedule
   @job_name = N'sp_delete_backuphistory',
   @schedule_name = N'WeeklySun1202' ;
GO

EXEC sp_attach_schedule
   @job_name = N'sp_purge_jobhistory',
   @schedule_name = N'WeeklySun1203' ;
GO
