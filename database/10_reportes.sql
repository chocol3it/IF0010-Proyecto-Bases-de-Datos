/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   10 - Reportes (REQ 007)
   -------------------------------------------------------------
   Todos los reportes:
     - usan TRY/CATCH y BEGIN/COMMIT/ROLLBACK TRANSACTION,
     - filtran fechas con rangos (>= desde AND < hasta + 1 día) para
       que SQL Server pueda usar índices sobre la columna de fecha,
     - trabajan con nivel de aislamiento SNAPSHOT.

   ¿Por qué SNAPSHOT?
     Un reporte solo lee, pero lo hace sobre muchas filas mientras
     los digitadores siguen facturando.
     - READ UNCOMMITTED: no bloquea, pero permite lecturas sucias
       (montos de facturas que luego se revierten). Inaceptable en
       datos financieros.
     - READ COMMITTED (por defecto): no hay lecturas sucias, pero el
       reporte espera a que terminen las transacciones de escritura
       y puede mezclar datos de antes y después de un cambio.
     - REPEATABLE READ / SERIALIZABLE: consistentes, pero bloquean a
       los digitadores mientras dura el reporte.
     - SNAPSHOT: lee una "foto" consistente de los datos confirmados
       al inicio de la transacción (versionado de filas en tempdb).
       No bloquea ni es bloqueado por las escrituras y no tiene
       lecturas sucias. Requiere ALLOW_SNAPSHOT_ISOLATION ON
       (ver 00_crear_bd.sql).
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_rpt_clientes
   Reporte de clientes resumido.
   @cod_estado: 'A' activos, 'I' inactivos, NULL todos.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_clientes
    @fec_desde  DATE,
    @fec_hasta  DATE,
    @cod_estado CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT c.nom_cliente,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
               c.des_actividad_economica,
               CONVERT(VARCHAR(150), DECRYPTBYKEY(c.des_correo)) AS des_correo,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_telefono)) AS num_telefono
        FROM facturacion.clientes c
        WHERE c.fec_registro >= @fec_desde
          AND c.fec_registro < DATEADD(DAY, 1, @fec_hasta)
          AND (@cod_estado IS NULL OR c.cod_estado = @cod_estado)
        ORDER BY c.nom_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_facturas
   Reporte de facturas por rango de fechas de la factura.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_facturas
    @fec_desde DATE,
    @fec_hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT c.nom_cliente,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
               c.des_actividad_economica,
               f.cod_factura, f.fec_factura,
               f.mon_subtotal, f.mon_total_impuestos, f.mon_total
        FROM facturacion.facturas f
        JOIN facturacion.clientes c ON c.cod_cliente = f.cod_cliente
        WHERE f.fec_factura >= @fec_desde
          AND f.fec_factura < DATEADD(DAY, 1, @fec_hasta)
        ORDER BY f.fec_factura, f.cod_factura;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_auditoria
   Reporte de pistas de auditoría.
   @cod_usuario: un usuario específico o NULL para todos.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_auditoria
    @fec_desde   DATE,
    @fec_hasta   DATE,
    @cod_usuario VARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT b.fec_registro,
               CASE b.ind_accion
                   WHEN 'I' THEN 'Inserción'
                   WHEN 'D' THEN 'Borrado'
                   WHEN 'U' THEN 'Modificación'
               END AS des_accion,
               RTRIM(b.cod_usuario) AS cod_usuario,
               b.cod_tabla,
               b.cod_llave,
               b.des_datos
        FROM auditoria.bitacora_auditoria b
        WHERE b.fec_registro >= @fec_desde
          AND b.fec_registro < DATEADD(DAY, 1, @fec_hasta)
          AND (@cod_usuario IS NULL OR b.cod_usuario = @cod_usuario)
        ORDER BY b.fec_registro DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_seguridad
   Reporte de configuración de seguridad: permisos de cada usuario
   (directos o heredados de su rol) sobre los objetos de la BD.
   @nom_usuario: un usuario específico o NULL para todos.
   WITH EXECUTE AS OWNER: las vistas del sistema solo muestran lo
   que el usuario conectado puede ver; el reporte se ejecuta con
   los permisos del dueño (dbo) para listar la configuración completa.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_seguridad
    @nom_usuario VARCHAR(128) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT u.name AS nom_usuario,
               ISNULL(r.name, '(sin rol)') AS nom_rol,
               CASE p.class
                   WHEN 1 THEN OBJECT_SCHEMA_NAME(p.major_id) + '.' + OBJECT_NAME(p.major_id)
                   WHEN 3 THEN SCHEMA_NAME(p.major_id)
                   WHEN 4 THEN USER_NAME(p.major_id)
                   WHEN 24 THEN (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = p.major_id)
                   WHEN 25 THEN (SELECT name FROM sys.certificates WHERE certificate_id = p.major_id)
                   ELSE DB_NAME()
               END AS nom_objeto,
               CASE
                   WHEN p.class = 1 THEN
                       CASE o.type
                           WHEN 'U'  THEN 'Tabla'
                           WHEN 'V'  THEN 'Vista'
                           WHEN 'P'  THEN 'Procedimiento'
                           WHEN 'FN' THEN 'Función'
                           WHEN 'IF' THEN 'Función'
                           WHEN 'TF' THEN 'Función'
                           ELSE o.type_desc
                       END
                   WHEN p.class = 3  THEN 'Esquema'
                   WHEN p.class = 4  THEN 'Usuario'
                   WHEN p.class = 24 THEN 'Llave simétrica'
                   WHEN p.class = 25 THEN 'Certificado'
                   ELSE 'Base de datos'
               END AS des_tipo_objeto,
               CASE p.permission_name
                   WHEN 'SELECT'  THEN 'Selección'
                   WHEN 'INSERT'  THEN 'Inserción'
                   WHEN 'DELETE'  THEN 'Borrado'
                   WHEN 'UPDATE'  THEN 'Modificación'
                   WHEN 'EXECUTE' THEN 'Execute'
                   ELSE p.permission_name
               END AS des_permiso,
               p.state_desc AS des_estado_permiso
        FROM sys.database_principals u
        LEFT JOIN sys.database_role_members rm ON rm.member_principal_id = u.principal_id
        LEFT JOIN sys.database_principals r    ON r.principal_id = rm.role_principal_id
        JOIN sys.database_permissions p
             ON p.grantee_principal_id = u.principal_id
             OR p.grantee_principal_id = r.principal_id
        LEFT JOIN sys.objects o ON p.class = 1 AND o.object_id = p.major_id
        WHERE u.type = 'S'
          AND u.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
          AND p.permission_name <> 'CONNECT'
          AND (@nom_usuario IS NULL OR u.name = @nom_usuario)
        ORDER BY u.name, nom_objeto, des_permiso;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
