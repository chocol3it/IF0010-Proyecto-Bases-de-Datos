/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   04 - Pistas de auditoría de Clientes (REQ 005)
   -------------------------------------------------------------
   Un trigger por acción (INSERT, UPDATE, DELETE). Cada fila
   afectada genera una fila en auditoria.bitacora_auditoria, así
   funcionan también con operaciones de varias filas.
     cod_usuario        -> login de SQL Server que hizo el cambio
     cod_sesion_usuario -> id de sesión guardado en SESSION_CONTEXT
                           al iniciar sesión en la aplicación
     des_datos          -> la fila en formato JSON (en UPDATE,
                           el antes y el después)
   Este mismo patrón se repite para las demás tablas.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

CREATE OR ALTER TRIGGER facturacion.tr_clientes_insert
ON facturacion.clientes
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.clientes',
           CAST(i.cod_cliente AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_cliente = i.cod_cliente
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_clientes_update
ON facturacion.clientes
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.clientes',
           CAST(i.cod_cliente AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_cliente = i.cod_cliente
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_cliente = i.cod_cliente
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_clientes_delete
ON facturacion.clientes
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.clientes',
           CAST(d.cod_cliente AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_cliente = d.cod_cliente
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO
