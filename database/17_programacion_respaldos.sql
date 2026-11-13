--Proyecto IF0010 - Sistema de Facturación Propi
--17 - Programación de respaldos con el Agente SQL (REQ 013)
--Requiere SQL Server Developer o Standard (Express no trae el Agente; ahí se usa el
--Programador de tareas de Windows con sqlcmd y los mismos EXEC de cada paso)
--Trabajos:
--  Propi - Respaldo completo     domingo 00:30
--  Propi - Respaldo diferencial  lunes a sábado 00:30
--  Propi - Respaldo de log       cada 30 segundos (RPO de los respaldos y del REQ 014)
--  Propi - Respaldo de llaves    día 1 de cada mes 00:15
--  Propi - Limpieza de respaldos diario 02:00 (.bak 35 días, .trn 8 días)
--Se puede ejecutar varias veces: borra y vuelve a crear los trabajos
USE msdb;
GO

DECLARE @ruta NVARCHAR(260) = N'C:\PropiRespaldos\';
DECLARE @base SYSNAME = N'PropiFacturacion_AAMM';
DECLARE @trabajos TABLE (n INT IDENTITY, nombre SYSNAME, comando NVARCHAR(MAX),
                         freq_type INT, freq_interval INT, subday_type INT, subday_interval INT, hora INT);

INSERT INTO @trabajos VALUES
(N'Propi - Respaldo completo',     CONCAT(N'EXEC dbo.pa_respaldar ''COMPLETO'', N''', @ruta, N''';'),    8, 1,  1, 0,  3000),
(N'Propi - Respaldo diferencial',  CONCAT(N'EXEC dbo.pa_respaldar ''DIFERENCIAL'', N''', @ruta, N''';'), 8, 126, 1, 0, 3000),
(N'Propi - Respaldo de log',       CONCAT(N'EXEC dbo.pa_respaldar ''LOG'', N''', @ruta, N''';'),         4, 1,  2, 30, 0),
(N'Propi - Respaldo de llaves',    CONCAT(N'EXEC dbo.pa_respaldar ''LLAVES'', N''', @ruta, N''', N''Propi#Llaves2026'';'), 16, 1, 1, 0, 1500),
(N'Propi - Limpieza de respaldos', CONCAT(N'DECLARE @f1 DATETIME = DATEADD(DAY, -35, GETDATE()), @f2 DATETIME = DATEADD(DAY, -8, GETDATE());',
                                          N'EXEC master.sys.xp_delete_file 0, N''', @ruta, N''', N''bak'', @f1, 0;',
                                          N'EXEC master.sys.xp_delete_file 0, N''', @ruta, N''', N''trn'', @f2, 0;'), 4, 1, 1, 0, 20000);

DECLARE @i INT = 1, @nombre SYSNAME, @comando NVARCHAR(MAX), @ft INT, @fi INT, @st INT, @si INT, @hora INT;
DECLARE @id UNIQUEIDENTIFIER;

WHILE @i <= (SELECT COUNT(*) FROM @trabajos)
BEGIN
    SELECT @nombre = nombre, @comando = comando, @ft = freq_type, @fi = freq_interval,
           @st = subday_type, @si = subday_interval, @hora = hora
    FROM @trabajos WHERE n = @i;

    IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @nombre)
        EXEC dbo.sp_delete_job @job_name = @nombre;

    SET @id = NULL;
    EXEC dbo.sp_add_job @job_name = @nombre, @enabled = 1, @owner_login_name = N'sa',
         @description = N'Respaldos de Propi (REQ 013)', @job_id = @id OUTPUT;
    EXEC dbo.sp_add_jobstep @job_id = @id, @step_name = N'Ejecutar', @subsystem = N'TSQL',
         @database_name = @base, @command = @comando, @retry_attempts = 1, @retry_interval = 1;
    EXEC dbo.sp_add_jobschedule @job_id = @id, @name = @nombre, @enabled = 1,
         @freq_type = @ft, @freq_interval = @fi, @freq_recurrence_factor = 1,
         @freq_subday_type = @st, @freq_subday_interval = @si, @active_start_time = @hora;
    EXEC dbo.sp_add_jobserver @job_id = @id, @server_name = N'(local)';

    SET @i += 1;
END;
GO

--Trabajos creados
SELECT j.name AS trabajo, j.enabled AS habilitado, s.name AS horario,
       CASE s.freq_type WHEN 4 THEN 'Diario' WHEN 8 THEN 'Semanal' WHEN 16 THEN 'Mensual' END AS frecuencia,
       CASE s.freq_subday_type WHEN 2 THEN CONCAT('cada ', s.freq_subday_interval, ' segundos') END AS repeticion
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
WHERE j.name LIKE N'Propi - %'
ORDER BY j.name;
GO
