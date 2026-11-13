--Proyecto IF0010 - Sistema de Facturación Propi
--18 - Restauración de prueba (REQ 013)
--Restaura la cadena de respaldos más reciente de la carpeta en una base con otro nombre:
--completo -> diferencial -> logs (WITH NORECOVERY) -> RECOVERY, luego las llaves y la verificación
--Sirve igual en la misma instancia o en otro servidor que vea la carpeta de respaldos
--@hasta permite restaurar a un punto en el tiempo (NULL = hasta el último log)
USE master;
GO
SET NOCOUNT ON;

DECLARE @ruta      NVARCHAR(260) = N'C:\PropiRespaldos\';
DECLARE @origen    SYSNAME       = N'PropiFacturacion_AAMM';
DECLARE @destino   SYSNAME       = N'PropiFacturacion_AAMM_prueba';
DECLARE @clave_dmk NVARCHAR(128) = N'Propi#MasterKey2026';
DECLARE @hasta     DATETIME      = NULL;

DECLARE @datos NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @logs  NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260));
DECLARE @sql NVARCHAR(MAX), @archivo NVARCHAR(400), @mover NVARCHAR(MAX), @stopat NVARCHAR(100) = N'';

--Archivos de la carpeta (el nombre lleva la fecha, así que el orden alfabético es el cronológico)
CREATE TABLE #archivos (archivo NVARCHAR(400), profundidad INT, es_archivo INT);
INSERT INTO #archivos EXEC master.sys.xp_dirtree @ruta, 1, 1;

DECLARE @completo NVARCHAR(400) = (SELECT MAX(archivo) FROM #archivos
                                   WHERE archivo LIKE @origen + N'[_]completo[_]%.bak');
IF @completo IS NULL
    THROW 50002, 'No hay respaldo completo en la carpeta.', 1;

DECLARE @diferencial NVARCHAR(400) = (SELECT MAX(archivo) FROM #archivos
                                      WHERE archivo LIKE @origen + N'[_]diferencial[_]%.bak'
                                        AND SUBSTRING(archivo, LEN(@origen) + 14, 19) > SUBSTRING(@completo, LEN(@origen) + 11, 19));

--Logs posteriores al último respaldo completo o diferencial
DECLARE @desde NVARCHAR(30) = ISNULL(SUBSTRING(@diferencial, LEN(@origen) + 14, 19), SUBSTRING(@completo, LEN(@origen) + 11, 19));
SELECT archivo, ROW_NUMBER() OVER (ORDER BY archivo) AS n
INTO #logs
FROM #archivos
WHERE archivo LIKE @origen + N'[_]log[_]%.trn'
  AND SUBSTRING(archivo, LEN(@origen) + 6, 19) > @desde;

PRINT CONCAT('Completo:    ', @completo);
PRINT CONCAT('Diferencial: ', ISNULL(@diferencial, '(ninguno)'));
DECLARE @cant_logs INT = (SELECT COUNT(*) FROM #logs);
PRINT CONCAT('Logs:        ', @cant_logs);

--Si la base de prueba ya existe se reemplaza
IF DB_ID(@destino) IS NOT NULL
BEGIN
    SET @sql = CONCAT(N'ALTER DATABASE ', QUOTENAME(@destino), N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ', QUOTENAME(@destino), N';');
    EXEC (@sql);
END;

--Los archivos se mueven a nombres nuevos para no chocar con la base original
SET @mover = CONCAT(
    N'MOVE N''PropiFacturacion_AAMM'' TO N''', @datos, @destino, N'.mdf'', ',
    N'MOVE N''PropiFacturacion_AAMM_auditoria'' TO N''', @datos, @destino, N'_auditoria.ndf'', ',
    N'MOVE N''PropiFacturacion_AAMM_log'' TO N''', @logs, @destino, N'_log.ldf''');
IF @hasta IS NOT NULL
    SET @stopat = CONCAT(N', STOPAT = ''', CONVERT(NVARCHAR(30), @hasta, 126), N'''');

--1. Completo
SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@destino), N' FROM DISK = N''', @ruta, @completo,
                  N''' WITH NORECOVERY, CHECKSUM, ', @mover, N';');
EXEC (@sql);

--2. Diferencial
IF @diferencial IS NOT NULL
BEGIN
    SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@destino), N' FROM DISK = N''', @ruta, @diferencial,
                      N''' WITH NORECOVERY, CHECKSUM;');
    EXEC (@sql);
END;

--3. Logs en orden
DECLARE @i INT = 1;
WHILE @i <= @cant_logs
BEGIN
    SELECT @archivo = archivo FROM #logs WHERE n = @i;
    SET @sql = CONCAT(N'RESTORE LOG ', QUOTENAME(@destino), N' FROM DISK = N''', @ruta, @archivo,
                      N''' WITH NORECOVERY, CHECKSUM', @stopat, N';');
    EXEC (@sql);
    SET @i += 1;
END;

--4. Se deja la base disponible
SET @sql = CONCAT(N'RESTORE DATABASE ', QUOTENAME(@destino), N' WITH RECOVERY;');
EXEC (@sql);

--5. Llaves: la master key viaja dentro de la base, pero protegida por la llave de servicio
--del servidor original. Se abre con su contraseña y se protege con la de este servidor
SET @sql = CONCAT(N'USE ', QUOTENAME(@destino), N';
OPEN MASTER KEY DECRYPTION BY PASSWORD = ''', REPLACE(@clave_dmk, '''', ''''''), N''';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
CLOSE MASTER KEY;');
EXEC (@sql);

--Si se perdió la contraseña de la master key, se restaura desde su archivo de respaldo:
--RESTORE MASTER KEY FROM FILE = 'C:\PropiRespaldos\..._master_key_....key'
--    DECRYPTION BY PASSWORD = 'Propi#Llaves2026' ENCRYPTION BY PASSWORD = 'NuevaClave#2026' FORCE;
--Y si se perdió el certificado:
--CREATE CERTIFICATE cert_clientes FROM FILE = '..._cert_clientes_....cer'
--    WITH PRIVATE KEY (FILE = '..._cert_clientes_....pvk', DECRYPTION BY PASSWORD = 'Propi#Llaves2026');

--6. Verificación: integridad, cantidad de registros y lectura de datos cifrados
SET @sql = CONCAT(N'USE ', QUOTENAME(@destino), N';
DBCC CHECKDB WITH NO_INFOMSGS;
SELECT ''clientes'' AS tabla, COUNT(*) AS registros FROM facturacion.clientes
UNION ALL SELECT ''facturas'', COUNT(*) FROM facturacion.facturas
UNION ALL SELECT ''facturas_detalle'', COUNT(*) FROM facturacion.facturas_detalle
UNION ALL SELECT ''notas_credito_debito'', COUNT(*) FROM facturacion.notas_credito_debito
UNION ALL SELECT ''bitacora_auditoria'', COUNT(*) FROM auditoria.bitacora_auditoria;
OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;
SELECT TOP 3 cod_cliente, nom_cliente,
       CONVERT(VARCHAR(20), DECRYPTBYKEY(num_identificacion)) AS identificacion,
       CONVERT(VARCHAR(150), DECRYPTBYKEY(des_correo)) AS correo
FROM facturacion.clientes ORDER BY cod_cliente DESC;
CLOSE SYMMETRIC KEY llave_clientes;');
EXEC (@sql);

DROP TABLE #archivos, #logs;
GO

--Para borrar la base de prueba al terminar:
--ALTER DATABASE PropiFacturacion_AAMM_prueba SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--DROP DATABASE PropiFacturacion_AAMM_prueba;
