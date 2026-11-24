--Proyecto IF0010 - Sistema de Facturación Propi
--Anexo 7 - Demostración de los requerimientos en SSMS (defensa)
--Uso: conectarse como sysadmin a la principal (AMS-LAPTOP\SQLUCR), seleccionar UN bloque y ejecutarlo con F5.
--     Los bloques del REQ 014 marcados "SECUNDARIA" se ejecutan conectado a AMS-LAPTOP\SQLSERVERSJ.
--Los bloques con EXECUTE AS terminan en REVERT. Si uno se corta antes por un error,
--ejecutar REVERT; y confirmar con SELECT SUSER_SNAME(); que vuelve a ser el usuario de Windows.
USE PropiFacturacion_AAMM;
GO

/* ========================================================================
   REQ 001 - Modelo: esquemas, tablas, filegroups y relaciones
   ======================================================================== */
-- 15 tablas en dos esquemas; las bitácoras viven en el filegroup FG_AUDITORIA
SELECT s.name AS esquema, t.name AS tabla, fg.name AS filegroup
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id IN (0, 1)
JOIN sys.filegroups fg ON fg.data_space_id = i.data_space_id
WHERE s.name IN ('facturacion', 'auditoria')
ORDER BY s.name, t.name;

-- Llaves foráneas (las relaciones del modelo)
SELECT OBJECT_NAME(fk.parent_object_id) AS tabla, fk.name AS llave_foranea,
       OBJECT_NAME(fk.referenced_object_id) AS referencia
FROM sys.foreign_keys fk
ORDER BY tabla;

-- Archivos físicos de la base (.mdf, .ndf de auditoría y .ldf)
SELECT name, type_desc, physical_name FROM sys.database_files;
GO

/* ========================================================================
   REQ 003 - Ingreso: el rol lo decide SQL Server y queda en la bitácora
   ======================================================================== */
-- Logins de SQL Server (no hay tabla de usuarios propia)
SELECT name, type_desc, is_disabled, is_policy_checked FROM sys.sql_logins WHERE name LIKE 'propi[_]%';

-- Lo que hace el backend al iniciar sesión: se ejecuta como el login y registra el ingreso
EXECUTE AS LOGIN = 'propi_admin';
EXEC auditoria.pa_acceso_ingresar @nom_terminal = 'PC-DEFENSA', @des_direccion_ip = '127.0.0.1';
REVERT;

SELECT TOP 5 * FROM auditoria.bitacora_acceso ORDER BY cod_acceso DESC;
GO

/* ========================================================================
   REQ 004 - Roles y sus miembros
   ======================================================================== */
SELECT r.name AS rol, u.name AS usuario
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
WHERE r.name LIKE 'rol[_]%'
ORDER BY r.name;
GO

/* ========================================================================
   REQ 002 - CRUD por procedimientos (como lo hace la aplicación)
   ======================================================================== */
-- El backend fija la sesión y ejecuta como el usuario que inició sesión
DECLARE @sesion INT = (SELECT MAX(cod_acceso) FROM auditoria.bitacora_acceso WHERE nom_usuario = 'propi_admin');
EXEC sp_set_session_context @key = N'cod_sesion', @value = @sesion;
EXECUTE AS USER = 'propi_admin';

-- Factura con dos líneas en JSON: encabezado, líneas y totales en una sola transacción
EXEC facturacion.pa_facturas_insertar
     @cod_cliente = 1, @cod_condicion_venta = 1, @cod_medio_pago = 5, @cod_moneda = 1,
     @mon_tipo_cambio = 1, @des_observaciones = 'Factura de la defensa',
     @detalle = N'[{"codProducto":2,"canCantidad":2},{"codProducto":3,"canCantidad":1}]';
REVERT;

DECLARE @factura INT = (SELECT MAX(cod_factura) FROM facturacion.facturas);
EXECUTE AS USER = 'propi_admin';
EXEC facturacion.pa_facturas_consultar @factura;
EXEC facturacion.pa_facturas_detalle_consultar @factura;

-- Nota de crédito válida
EXEC facturacion.pa_notas_insertar @factura, 1, 'Descuento por pronto pago', 1000;
EXEC facturacion.pa_notas_consultar NULL, @factura;
REVERT;
GO

-- Regla de negocio: una nota de crédito mayor que el total se rechaza (THROW 50003)
DECLARE @factura INT = (SELECT MAX(cod_factura) FROM facturacion.facturas);
EXEC facturacion.pa_notas_insertar @factura, 1, 'Nota excesiva', 99999999;
GO

-- Regla de negocio: una factura con notas no se puede eliminar (THROW 50003)
DECLARE @factura INT = (SELECT MAX(cod_factura) FROM facturacion.facturas);
EXEC facturacion.pa_facturas_eliminar @factura;
GO

/* ========================================================================
   REQ 005 - Triggers de auditoría (3 por tabla) y bitácora
   ======================================================================== */
SELECT OBJECT_NAME(parent_id) AS tabla, COUNT(*) AS triggers
FROM sys.triggers WHERE parent_class = 1
GROUP BY OBJECT_NAME(parent_id) ORDER BY tabla;

-- Una modificación hecha como propi_admin queda con su usuario, su sesión y los datos de antes y después
DECLARE @sesion INT = (SELECT MAX(cod_acceso) FROM auditoria.bitacora_acceso WHERE nom_usuario = 'propi_admin');
EXEC sp_set_session_context @key = N'cod_sesion', @value = @sesion;
DECLARE @factura INT = (SELECT MAX(cod_factura) FROM facturacion.facturas);
EXECUTE AS USER = 'propi_admin';
EXEC facturacion.pa_facturas_actualizar @factura, 2, 3, 'Observación modificada en la defensa';
REVERT;

SELECT TOP 6 fec_registro, ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos
FROM auditoria.bitacora_auditoria ORDER BY fec_registro DESC;
GO

/* ========================================================================
   REQ 006 - Cifrado de la identificación, el correo y el teléfono
   ======================================================================== */
SELECT name, algorithm_desc, key_length FROM sys.symmetric_keys WHERE name = 'llave_clientes';
SELECT name, pvt_key_encryption_type_desc FROM sys.certificates WHERE name = 'cert_clientes';

-- Así se guarda en la tabla: solo bytes
SELECT TOP 3 cod_cliente, nom_cliente, num_identificacion, des_correo, cod_hash_identificacion
FROM facturacion.clientes ORDER BY cod_cliente DESC;

-- Así lo lee el procedimiento con la llave abierta
OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;
SELECT TOP 3 cod_cliente, nom_cliente,
       CONVERT(VARCHAR(20), DECRYPTBYKEY(num_identificacion)) AS identificacion,
       CONVERT(VARCHAR(150), DECRYPTBYKEY(des_correo)) AS correo,
       CONVERT(VARCHAR(20), DECRYPTBYKEY(num_telefono)) AS telefono
FROM facturacion.clientes ORDER BY cod_cliente DESC;
CLOSE SYMMETRIC KEY llave_clientes;
GO

/* ========================================================================
   REQ 007 - Reportes con aislamiento SNAPSHOT (ejecutados como propi_consulta)
   ======================================================================== */
SELECT name, snapshot_isolation_state_desc FROM sys.databases WHERE name = DB_NAME();

DECLARE @desde DATE = DATEADD(DAY, -30, GETDATE()), @hasta DATE = GETDATE();
EXECUTE AS USER = 'propi_consulta';
EXEC facturacion.pa_rpt_clientes @desde, @hasta, NULL;
EXEC facturacion.pa_rpt_facturas @desde, @hasta;
EXEC facturacion.pa_rpt_auditoria @desde, @hasta, 'propi_admin';
EXEC facturacion.pa_rpt_seguridad NULL;
REVERT;
GO

/* ========================================================================
   REQ 008 - GRANT, REVOKE y DENY
   ======================================================================== */
-- Permisos por rol: GRANT de procedimientos y DENY sobre los esquemas
SELECT pr.name AS rol, pe.state_desc AS estado, pe.permission_name AS permiso,
       CASE pe.class WHEN 3 THEN SCHEMA_NAME(pe.major_id)
                     WHEN 1 THEN OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id)
                     WHEN 4 THEN USER_NAME(pe.major_id)
                     ELSE pe.class_desc END AS sobre
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE 'rol[_]%' OR pr.name = 'propi_app'
ORDER BY pr.name, pe.state_desc, sobre;

-- El digitador no puede leer la tabla ni eliminar: error 229 aunque se salte la aplicación
EXECUTE AS USER = 'propi_digitador';
SELECT TOP 1 * FROM facturacion.clientes;              -- DENY SELECT sobre el esquema
EXEC facturacion.pa_facturas_eliminar 1;               -- DENY EXECUTE sobre el procedimiento
EXEC facturacion.pa_clientes_consultar 1;              -- funciona: encadenamiento de propiedad
REVERT;
GO

/* ========================================================================
   REQ 009 - Índices y planes de ejecución (activar antes Ctrl+M)
   ======================================================================== */
SELECT OBJECT_NAME(object_id) AS tabla, name AS indice, type_desc
FROM sys.indexes WHERE name LIKE 'IX[_]%' ORDER BY tabla;

-- Con el índice: Clustered Index Seek y pocas lecturas (ver pestaña Mensajes)
SET STATISTICS IO ON;
DECLARE @desde DATE = DATEADD(DAY, -30, GETDATE()), @hasta DATE = GETDATE();
EXEC facturacion.pa_rpt_auditoria @desde, @hasta, NULL;
SET STATISTICS IO OFF;
GO

-- Sin el índice: la bitácora se lee completa (Table Scan). Al final se vuelve a crear
DROP INDEX IX_bitacora_auditoria_fec_registro ON auditoria.bitacora_auditoria;
SET STATISTICS IO ON;
DECLARE @desde DATE = DATEADD(DAY, -30, GETDATE()), @hasta DATE = GETDATE();
EXEC facturacion.pa_rpt_auditoria @desde, @hasta, NULL;
SET STATISTICS IO OFF;
CREATE CLUSTERED INDEX IX_bitacora_auditoria_fec_registro
    ON auditoria.bitacora_auditoria (fec_registro) ON FG_AUDITORIA;
GO

/* ========================================================================
   REQ 010 - Diccionario de datos guardado en la base
   ======================================================================== */
SELECT * FROM dbo.v_diccionario_tablas;
SELECT * FROM dbo.v_diccionario_columnas WHERE tabla = 'clientes';
SELECT * FROM dbo.v_diccionario_restricciones WHERE tabla = 'facturas';
GO

/* ========================================================================
   REQ 012 - Seguridad en tránsito: conexiones cifradas con TLS
   ======================================================================== */
-- Las conexiones del backend (propi_app) aparecen con encrypt_option = TRUE
SELECT c.session_id, s.login_name, c.encrypt_option, c.auth_scheme, c.client_net_address
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE s.is_user_process = 1;
GO

/* ========================================================================
   REQ 013 - Respaldos: modelo FULL, historial y trabajos del Agente
   ======================================================================== */
SELECT name, recovery_model_desc FROM sys.databases WHERE name = DB_NAME();

SELECT TOP 8 CASE b.type WHEN 'D' THEN 'Completo' WHEN 'I' THEN 'Diferencial' WHEN 'L' THEN 'Log' END AS tipo,
       b.backup_finish_date AS fecha, CAST(b.backup_size / 1048576 AS DECIMAL(10,2)) AS mb,
       m.physical_device_name AS archivo
FROM msdb.dbo.backupset b
JOIN msdb.dbo.backupmediafamily m ON m.media_set_id = b.media_set_id
WHERE b.database_name = DB_NAME()
ORDER BY b.backup_finish_date DESC;

SELECT j.name AS trabajo, j.enabled AS activo, s.name AS programacion
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
WHERE j.name LIKE 'Propi - %' ORDER BY j.name;
GO

/* ========================================================================
   REQ 014 - Réplica (SECUNDARIA: conectarse a AMS-LAPTOP\SQLSERVERSJ)
   ======================================================================== */
-- Estado: ONLINE y en STANDBY (solo lectura)
SELECT name, state_desc, is_in_standby, is_read_only FROM sys.databases WHERE name = 'PropiFacturacion_AAMM';

-- Atraso respecto de la principal (debe ser menor a 60 segundos)
SELECT TOP 1 rh.restore_date AS ultima_restauracion,
       bs.backup_finish_date AS respaldo_de_la_principal,
       DATEDIFF(SECOND, bs.backup_finish_date, GETDATE()) AS atraso_segundos
FROM msdb.dbo.restorehistory rh
JOIN msdb.dbo.backupset bs ON bs.backup_set_id = rh.backup_set_id
WHERE rh.destination_database_name = 'PropiFacturacion_AAMM'
ORDER BY rh.restore_history_id DESC;

-- La factura de la defensa ya llegó a la secundaria
SELECT TOP 3 cod_factura, fec_factura, des_observaciones
FROM PropiFacturacion_AAMM.facturacion.facturas ORDER BY cod_factura DESC;
GO

-- Simulacro de falla (ejecutar solo al final, en el orden indicado):
--   1. PRINCIPAL:  ALTER DATABASE PropiFacturacion_AAMM SET OFFLINE WITH ROLLBACK IMMEDIATE;
--   2. SECUNDARIA: EXEC master.dbo.pa_replica_activar;
--   3. Backend: cambiar el puerto a 1435 y levantar con .\mvnw.cmd clean spring-boot:run
-- Volver a la normalidad:
--   1. PRINCIPAL:  ALTER DATABASE PropiFacturacion_AAMM SET ONLINE;
--   2. Backend: volver al puerto 1433 y levantar con .\mvnw.cmd clean spring-boot:run
--   3. SECUNDARIA: USE master; ALTER DATABASE PropiFacturacion_AAMM SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--                  DROP DATABASE PropiFacturacion_AAMM;  y ejecutar anexos/05_replica_secundaria.sql
