"
DECLARE 
	@DatabaseName nvarchar(4000)
	,@tsql nvarchar(4000)

SET @DatabaseName = '$DestinationDatabase'

IF OBJECT_ID('tempdb..#DatabaseSessions') IS NOT NULL DROP TABLE #DatabaseSessions
CREATE TABLE #DatabaseSessions(session_id bigint, db_id bigint);

IF OBJECT_ID('master..sysprocesses') IS NOT NULL
	SET @tsql = N'INSERT INTO #DatabaseSessions SELECT S.spid ,S.dbid FROM master..sysprocesses S WHERE DB_NAME(S.dbid) = @DatabaseName;'
	
ELSE IF OBJECT_ID('sys.dm_tran_locks') IS NOT NULL
	SET @tsql = N'INSERT INTO #DatabaseSessions	SELECT TL.request_session_id ,TL.request_database_id FROM master.sys.dm_tran_locks TL WHERE DB_NAME(TL.request_database_id) = @DatabaseName;'

EXEC sp_executesql @tsql,N'@DatabaseName nvarchar(4000)',@DatabaseName;

SELECT
	s.session_id
	,s.login_name
	,s.login_time
	,s.status
	,R.request_id
	,R.command
	,R.wait_type
	,r.wait_time
FROM
	sys.dm_exec_sessions S
	JOIN
	#DatabaseSessions DS
		ON DS.session_id = S.session_id
	LEFT JOIN
	sys.dm_exec_requests R
		ON R.session_id = S.session_id
"