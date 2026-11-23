--Proyecto IF0010 - Sistema de Facturación Propi
--Anexo 5 - Base secundaria con log shipping (REQ 014)
--Se ejecuta en la instancia SECUNDARIA (SQL Server Developer), después de anexos/04_logins_secundaria.sql
--Funcionamiento:
--  Principal:  el trabajo "Propi - Respaldo de log" (17) respalda el log cada 30 segundos en la carpeta compartida
--  Secundaria: el trabajo "Propi - Aplicar logs de la réplica" restaura cada 15 segundos los logs nuevos
--              WITH STANDBY: la base queda de solo lectura y al día con la principal
--  Conmutación: EXEC master.dbo.pa_replica_activar deja la secundaria lista para escribir
--RPO: lo que no alcanzó a respaldarse en el log (máximo 30 segundos). RTO: ver docs/REQ014-replica.md
--La carpeta compartida debe poder leerla la cuenta del servicio de la secundaria
USE master;
GO

--Aplica en orden los respaldos de log que todavía no se han restaurado
CREATE OR ALTER PROCEDURE dbo.pa_replica_aplicar_logs
    @ruta     NVARCHAR(260) = N'C:\PropiRespaldos\',
    @base     SYSNAME       = N'PropiFacturacion_AAMM',
    @recovery BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @standby NVARCHAR(400) = CONCAT(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)), @base, N'_standby.tuf');
    DECLARE @ultimo NVARCHAR(400), @sello_ultimo VARCHAR(19), @archivo NVARCHAR(400), @sql NVARCHAR(MAX), @matar NVARCHAR(MAX) = N'';
    DECLARE @aplicados INT = 0;

    IF RIGHT(@ruta, 1) <> '\' SET @ruta += '\';

    --Último archivo restaurado en esta base (su nombre lleva la fecha y hora del respaldo)
    SELECT TOP 1 @ultimo = bmf.physical_device_name
    FROM msdb.dbo.restorehistory rh
    JOIN msdb.dbo.backupset bs ON bs.backup_set_id = rh.backup_set_id
    JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
    WHERE rh.destination_database_name = @base
    ORDER BY rh.restore_history_id DESC;

    IF @ultimo IS NULL
        THROW 50002, 'La base no se ha inicializado. Ejecute dbo.pa_replica_inicializar.', 1;

    SET @sello_ultimo = LEFT(RIGHT(@ultimo, 23), 19);

    CREATE TABLE #archivos (archivo NVARCHAR(400), profundidad INT, es_archivo INT);
    INSERT INTO #archivos EXEC master.sys.xp_dirtree @ruta, 1, 1;

    --La restauración necesita la base sin conexiones (en STANDBY se puede consultar)
    SELECT @matar += CONCAT(N'KILL ', session_id, N';')
    FROM sys.dm_exec_sessions
    WHERE database_id = DB_ID(@base) AND session_id <> @@SPID;
    IF @matar <> N'' EXEC (@matar);

    DECLARE logs CURSOR LOCAL FAST_FORWARD FOR
        SELECT archivo FROM #archivos
        WHERE archivo LIKE @base + N'[_]log[_]%.trn'
          AND LEFT(RIGHT(archivo, 23), 19) > @sello_ultimo
        ORDER BY archivo;
    OPEN logs;
    FETCH NEXT FROM logs INTO @archivo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = CONCAT(N'RESTORE LOG ', QUOTENAME(@base), N' FROM DISK = N''', @ruta, @archivo,
                          N''' WITH STANDBY = N''', @standby, N''';');
        BEGIN TRY
            EXEC (@sql);
            SET @aplicados += 1;
        END TRY
        BEGIN CATCH
            CLOSE logs;
            DEALLOCATE logs;
            THROW;
        END CATCH;
        FETCH NEXT FROM logs INTO @archivo;
    END;
    CLOSE logs;
    DEALLOCATE logs;

    IF @recovery = 1
    BEGIN
        SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@base), N' WITH RECOVERY;');
        EXEC (@sql);
    END;

    SELECT @aplicados AS logs_aplicados, SYSDATETIME() AS fecha;
END;
GO

--Copia inicial: último completo y diferencial de la carpeta WITH STANDBY, luego los logs
CREATE OR ALTER PROCEDURE dbo.pa_replica_inicializar
    @ruta NVARCHAR(260) = N'C:\PropiRespaldos\',
    @base SYSNAME       = N'PropiFacturacion_AAMM'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @datos NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
    DECLARE @logs NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260));
    DECLARE @standby NVARCHAR(400) = CONCAT(@datos, @base, N'_standby.tuf');
    DECLARE @completo NVARCHAR(400), @diferencial NVARCHAR(400), @sql NVARCHAR(MAX);

    IF RIGHT(@ruta, 1) <> '\' SET @ruta += '\';
    IF DB_ID(@base) IS NOT NULL
        THROW 50001, 'La base ya existe en esta instancia. Bórrela antes de inicializar la réplica.', 1;

    CREATE TABLE #archivos (archivo NVARCHAR(400), profundidad INT, es_archivo INT);
    INSERT INTO #archivos EXEC master.sys.xp_dirtree @ruta, 1, 1;

    SELECT @completo = MAX(archivo) FROM #archivos WHERE archivo LIKE @base + N'[_]completo[_]%.bak';
    IF @completo IS NULL
        THROW 50002, 'No hay respaldo completo en la carpeta.', 1;
    SELECT @diferencial = MAX(archivo) FROM #archivos
    WHERE archivo LIKE @base + N'[_]diferencial[_]%.bak'
      AND LEFT(RIGHT(archivo, 23), 19) > LEFT(RIGHT(@completo, 23), 19);

    SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@base), N' FROM DISK = N''', @ruta, @completo, N''' WITH ',
                      CASE WHEN @diferencial IS NULL THEN CONCAT(N'STANDBY = N''', @standby, N'''') ELSE N'NORECOVERY' END, N', ',
                      N'MOVE N''PropiFacturacion_AAMM'' TO N''', @datos, @base, N'.mdf'', ',
                      N'MOVE N''PropiFacturacion_AAMM_auditoria'' TO N''', @datos, @base, N'_auditoria.ndf'', ',
                      N'MOVE N''PropiFacturacion_AAMM_log'' TO N''', @logs, @base, N'_log.ldf'';');
    EXEC (@sql);

    IF @diferencial IS NOT NULL
    BEGIN
        SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@base), N' FROM DISK = N''', @ruta, @diferencial,
                          N''' WITH STANDBY = N''', @standby, N''';');
        EXEC (@sql);
    END;

    EXEC dbo.pa_replica_aplicar_logs @ruta, @base;
END;
GO

--Conmutación: la secundaria pasa a ser la base de trabajo
--Si la principal sigue encendida (cambio planeado), antes ejecutar en ella:
--  EXEC PropiFacturacion_AAMM.dbo.pa_respaldar 'LOG';   (o BACKUP LOG ... WITH NORECOVERY para dejarla de solo restauración)
CREATE OR ALTER PROCEDURE dbo.pa_replica_activar
    @ruta      NVARCHAR(260) = N'C:\PropiRespaldos\',
    @base      SYSNAME       = N'PropiFacturacion_AAMM',
    @clave_dmk NVARCHAR(128) = N'Propi#MasterKey2026'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @inicio DATETIME2 = SYSDATETIME(), @sql NVARCHAR(MAX), @login SYSNAME;

    --1. Últimos logs y RECOVERY: la base queda de lectura y escritura
    EXEC dbo.pa_replica_aplicar_logs @ruta, @base, 1;

    --2. La master key estaba protegida por la llave de servicio de la principal
    SET @sql = CONCAT(N'USE ', QUOTENAME(@base), N';
OPEN MASTER KEY DECRYPTION BY PASSWORD = ''', REPLACE(@clave_dmk, '''', ''''''), N''';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
CLOSE MASTER KEY;');
    EXEC (@sql);

    --3. Base por defecto de los logins de la aplicación
    DECLARE lg CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM sys.sql_logins WHERE name LIKE 'propi[_]%';
    OPEN lg;
    FETCH NEXT FROM lg INTO @login;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = CONCAT(N'ALTER LOGIN ', QUOTENAME(@login), N' WITH DEFAULT_DATABASE = ', QUOTENAME(@base), N';');
        EXEC (@sql);
        FETCH NEXT FROM lg INTO @login;
    END;
    CLOSE lg;
    DEALLOCATE lg;

    --4. Se detiene la aplicación de logs; desde ahora esta instancia es la principal
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Propi - Aplicar logs de la réplica')
        EXEC msdb.dbo.sp_update_job @job_name = N'Propi - Aplicar logs de la réplica', @enabled = 0;

    SELECT DATEDIFF(MILLISECOND, @inicio, SYSDATETIME()) AS ms_activacion,
           DATABASEPROPERTYEX(@base, 'Status') AS estado,
           DATABASEPROPERTYEX(@base, 'Updateability') AS escritura;
END;
GO

--Trabajo del Agente que mantiene la secundaria al día
USE msdb;
GO
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Propi - Aplicar logs de la réplica')
    EXEC dbo.sp_delete_job @job_name = N'Propi - Aplicar logs de la réplica';
DECLARE @id UNIQUEIDENTIFIER;
EXEC dbo.sp_add_job @job_name = N'Propi - Aplicar logs de la réplica', @enabled = 1, @owner_login_name = N'sa',
     @description = N'Log shipping de PropiFacturacion_AAMM (REQ 014)', @job_id = @id OUTPUT;
EXEC dbo.sp_add_jobstep @job_id = @id, @step_name = N'Aplicar logs', @subsystem = N'TSQL', @database_name = N'master',
     @command = N'EXEC dbo.pa_replica_aplicar_logs;';
EXEC dbo.sp_add_jobschedule @job_id = @id, @name = N'Cada 15 segundos', @enabled = 1,
     @freq_type = 4, @freq_interval = 1, @freq_subday_type = 2, @freq_subday_interval = 15;
EXEC dbo.sp_add_jobserver @job_id = @id, @server_name = N'(local)';
GO

--Copia inicial
USE master;
GO
EXEC dbo.pa_replica_inicializar;
GO

--Estado de la secundaria
SELECT name, state_desc, is_in_standby, is_read_only FROM sys.databases WHERE name = N'PropiFacturacion_AAMM';
GO
