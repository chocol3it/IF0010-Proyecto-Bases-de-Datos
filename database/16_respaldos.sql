--Proyecto IF0010 - Sistema de Facturación Propi
--16 - Respaldos (REQ 013)
--Modelo de recuperación FULL y procedimiento dbo.pa_respaldar para los respaldos
--completo, diferencial, de log y de las llaves de cifrado (master key y certificado)
--La carpeta de respaldos debe existir y la cuenta del servicio de SQL Server debe poder escribir en ella
USE master;
GO

--FULL guarda todo el log hasta respaldarlo: permite respaldos de log y restaurar a un punto en el tiempo
ALTER DATABASE PropiFacturacion_AAMM SET RECOVERY FULL;
GO

USE PropiFacturacion_AAMM;
GO

--@tipo: COMPLETO, DIFERENCIAL, LOG o LLAVES
--@ruta: carpeta destino; si es NULL usa la carpeta de respaldos de la instancia
--BACKUP no se puede ejecutar dentro de una transacción, por eso aquí solo hay TRY/CATCH
CREATE OR ALTER PROCEDURE dbo.pa_respaldar
    @tipo              VARCHAR(12),
    @ruta              NVARCHAR(260) = NULL,
    @contrasena_llaves NVARCHAR(128) = NULL,
    @archivo           NVARCHAR(400) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base SYSNAME = DB_NAME();
    DECLARE @sello VARCHAR(30) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss_fff');
    DECLARE @nombre NVARCHAR(128) = CONCAT(@base, ' ', @tipo, ' ', @sello);
    DECLARE @sql NVARCHAR(MAX), @archivo_cert NVARCHAR(400), @archivo_llave NVARCHAR(400);

    IF @ruta IS NULL SET @ruta = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF RIGHT(@ruta, 1) <> '\' SET @ruta += '\';

    BEGIN TRY
        IF @tipo = 'COMPLETO'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_completo_', @sello, '.bak');
            BACKUP DATABASE @base TO DISK = @archivo WITH CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'DIFERENCIAL'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_diferencial_', @sello, '.bak');
            BACKUP DATABASE @base TO DISK = @archivo WITH DIFFERENTIAL, CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'LOG'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_log_', @sello, '.trn');
            BACKUP LOG @base TO DISK = @archivo WITH CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'LLAVES'
        BEGIN
            --Sin la master key y el certificado no se pueden leer los datos cifrados de clientes
            IF @contrasena_llaves IS NULL
                THROW 50003, 'Debe indicar la contraseña con que se protegen los archivos de las llaves.', 1;

            SET @archivo = CONCAT(@ruta, @base, '_master_key_', @sello, '.key');
            SET @archivo_cert = CONCAT(@ruta, @base, '_cert_clientes_', @sello, '.cer');
            SET @archivo_llave = CONCAT(@ruta, @base, '_cert_clientes_', @sello, '.pvk');

            --Estas sentencias solo aceptan textos fijos, por eso se arman con SQL dinámico
            SET @sql = CONCAT(
                N'BACKUP MASTER KEY TO FILE = ''', REPLACE(@archivo, '''', ''''''), N''' ',
                N'ENCRYPTION BY PASSWORD = ''', REPLACE(@contrasena_llaves, '''', ''''''), N''';',
                N'BACKUP CERTIFICATE cert_clientes TO FILE = ''', REPLACE(@archivo_cert, '''', ''''''), N''' ',
                N'WITH PRIVATE KEY (FILE = ''', REPLACE(@archivo_llave, '''', ''''''), N''', ',
                N'ENCRYPTION BY PASSWORD = ''', REPLACE(@contrasena_llaves, '''', ''''''), N''');');
            EXEC sp_executesql @sql;
        END
        ELSE
            THROW 50003, 'Tipo de respaldo inválido. Use COMPLETO, DIFERENCIAL, LOG o LLAVES.', 1;

        --Comprueba que el archivo se pueda leer
        IF @tipo <> 'LLAVES'
            RESTORE VERIFYONLY FROM DISK = @archivo WITH CHECKSUM;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

--Primer juego de respaldos. Cambie la carpeta y la contraseña según el servidor
DECLARE @ruta NVARCHAR(260) = N'C:\PropiRespaldos\';
DECLARE @archivo NVARCHAR(400);

EXEC dbo.pa_respaldar 'LLAVES', @ruta, N'Propi#Llaves2026', @archivo OUTPUT;
PRINT CONCAT('Llaves: ', @archivo);
EXEC dbo.pa_respaldar 'COMPLETO', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Completo: ', @archivo);
EXEC dbo.pa_respaldar 'DIFERENCIAL', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Diferencial: ', @archivo);
EXEC dbo.pa_respaldar 'LOG', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Log: ', @archivo);
GO

--Historial de respaldos de la base
SELECT TOP 10 bs.backup_finish_date,
       CASE bs.type WHEN 'D' THEN 'Completo' WHEN 'I' THEN 'Diferencial' WHEN 'L' THEN 'Log' END AS tipo,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS tamano_mb,
       bmf.physical_device_name AS archivo
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'PropiFacturacion_AAMM'
ORDER BY bs.backup_finish_date DESC;
GO
