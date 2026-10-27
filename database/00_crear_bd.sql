/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   00 - Creación de la base de datos y almacenamiento
   -------------------------------------------------------------
   La base de datos se separa en dos filegroups:
     PRIMARY      -> tablas del negocio (esquema facturacion)
     FG_AUDITORIA -> bitácoras (esquema auditoria), que crecen
                     mucho más rápido y conviene tenerlas en su
                     propio archivo (.ndf).
   ============================================================= */
USE master;
GO

IF DB_ID('PropiFacturacion_AAMM') IS NULL
    CREATE DATABASE PropiFacturacion_AAMM;
GO

USE PropiFacturacion_AAMM;
GO

-- Filegroup para las bitácoras. El archivo .ndf se crea en la misma
-- carpeta del archivo principal (.mdf) de la base de datos.
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_AUDITORIA')
BEGIN
    DECLARE @ruta NVARCHAR(260);
    SELECT @ruta = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM sys.database_files
    WHERE file_id = 1;

    ALTER DATABASE PropiFacturacion_AAMM ADD FILEGROUP FG_AUDITORIA;

    EXEC ('ALTER DATABASE PropiFacturacion_AAMM ADD FILE (
               NAME = ''PropiFacturacion_AAMM_auditoria'',
               FILENAME = ''' + @ruta + 'PropiFacturacion_AAMM_auditoria.ndf'',
               SIZE = 8MB,
               FILEGROWTH = 8MB
           ) TO FILEGROUP FG_AUDITORIA');
END;
GO

-- Esquemas: uno para el negocio y otro para las bitácoras
IF SCHEMA_ID('facturacion') IS NULL EXEC ('CREATE SCHEMA facturacion');
GO
IF SCHEMA_ID('auditoria') IS NULL EXEC ('CREATE SCHEMA auditoria');
GO
