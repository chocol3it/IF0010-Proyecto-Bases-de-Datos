/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   09 - Pistas de auditoría (REQ 005)
   -------------------------------------------------------------
   Cada tabla tiene 3 triggers: uno para INSERT, uno para UPDATE
   y otro para DELETE. Todos siguen el mismo patrón:
     - Cada fila afectada genera una fila en la bitácora, así
       funcionan también con operaciones de varias filas.
     - inserted = filas nuevas, deleted = filas como estaban antes.
     cod_usuario        -> login de SQL Server que hizo el cambio
     cod_sesion_usuario -> código de sesión que la aplicación guarda
                           en SESSION_CONTEXT al iniciar sesión
     cod_llave          -> llave primaria del registro afectado
     des_datos          -> la fila en formato JSON (en UPDATE, el
                           antes y el después)
   El trigger corre dentro de la misma transacción del cambio: si
   no se puede escribir en la bitácora, el cambio también se revierte.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ---------------------------- estados ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_estados_insert
ON facturacion.estados
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.estados',
           CAST(i.cod_estado AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_estado = i.cod_estado
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_estados_update
ON facturacion.estados
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.estados',
           CAST(i.cod_estado AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_estado = i.cod_estado
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_estado = i.cod_estado
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_estados_delete
ON facturacion.estados
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.estados',
           CAST(d.cod_estado AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_estado = d.cod_estado
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- tipos_identificacion ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_insert
ON facturacion.tipos_identificacion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_identificacion',
           CAST(i.cod_tipo_identificacion AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_update
ON facturacion.tipos_identificacion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_identificacion',
           CAST(i.cod_tipo_identificacion AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_delete
ON facturacion.tipos_identificacion
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_identificacion',
           CAST(d.cod_tipo_identificacion AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_tipo_identificacion = d.cod_tipo_identificacion
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- condiciones_venta ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_insert
ON facturacion.condiciones_venta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.condiciones_venta',
           CAST(i.cod_condicion_venta AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_condicion_venta = i.cod_condicion_venta
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_update
ON facturacion.condiciones_venta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.condiciones_venta',
           CAST(i.cod_condicion_venta AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_condicion_venta = i.cod_condicion_venta
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_condicion_venta = i.cod_condicion_venta
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_delete
ON facturacion.condiciones_venta
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.condiciones_venta',
           CAST(d.cod_condicion_venta AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_condicion_venta = d.cod_condicion_venta
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- medios_pago ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_insert
ON facturacion.medios_pago
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.medios_pago',
           CAST(i.cod_medio_pago AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_medio_pago = i.cod_medio_pago
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_update
ON facturacion.medios_pago
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.medios_pago',
           CAST(i.cod_medio_pago AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_medio_pago = i.cod_medio_pago
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_medio_pago = i.cod_medio_pago
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_delete
ON facturacion.medios_pago
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.medios_pago',
           CAST(d.cod_medio_pago AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_medio_pago = d.cod_medio_pago
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- monedas ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_monedas_insert
ON facturacion.monedas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.monedas',
           CAST(i.cod_moneda AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_moneda = i.cod_moneda
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_monedas_update
ON facturacion.monedas
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.monedas',
           CAST(i.cod_moneda AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_moneda = i.cod_moneda
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_moneda = i.cod_moneda
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_monedas_delete
ON facturacion.monedas
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.monedas',
           CAST(d.cod_moneda AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_moneda = d.cod_moneda
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- unidades_medida ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_insert
ON facturacion.unidades_medida
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.unidades_medida',
           CAST(i.cod_unidad_medida AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_unidad_medida = i.cod_unidad_medida
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_update
ON facturacion.unidades_medida
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.unidades_medida',
           CAST(i.cod_unidad_medida AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_unidad_medida = i.cod_unidad_medida
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_unidad_medida = i.cod_unidad_medida
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_delete
ON facturacion.unidades_medida
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.unidades_medida',
           CAST(d.cod_unidad_medida AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_unidad_medida = d.cod_unidad_medida
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- tipos_nota ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_insert
ON facturacion.tipos_nota
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_nota',
           CAST(i.cod_tipo_nota AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_tipo_nota = i.cod_tipo_nota
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_update
ON facturacion.tipos_nota
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_nota',
           CAST(i.cod_tipo_nota AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_tipo_nota = i.cod_tipo_nota
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_tipo_nota = i.cod_tipo_nota
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_delete
ON facturacion.tipos_nota
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_nota',
           CAST(d.cod_tipo_nota AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_tipo_nota = d.cod_tipo_nota
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- clientes ---------------------------- */

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

/* ---------------------------- tipos_impuesto ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_insert
ON facturacion.tipos_impuesto
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_impuesto',
           CAST(i.cod_tipo_impuesto AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_update
ON facturacion.tipos_impuesto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_impuesto',
           CAST(i.cod_tipo_impuesto AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_delete
ON facturacion.tipos_impuesto
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.tipos_impuesto',
           CAST(d.cod_tipo_impuesto AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_tipo_impuesto = d.cod_tipo_impuesto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- productos_servicios ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_insert
ON facturacion.productos_servicios
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.productos_servicios',
           CAST(i.cod_producto AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_producto = i.cod_producto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_update
ON facturacion.productos_servicios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.productos_servicios',
           CAST(i.cod_producto AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_producto = i.cod_producto
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_producto = i.cod_producto
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_delete
ON facturacion.productos_servicios
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.productos_servicios',
           CAST(d.cod_producto AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_producto = d.cod_producto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- facturas ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_facturas_insert
ON facturacion.facturas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas',
           CAST(i.cod_factura AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_factura = i.cod_factura
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_facturas_update
ON facturacion.facturas
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas',
           CAST(i.cod_factura AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_factura = i.cod_factura
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_factura = i.cod_factura
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_facturas_delete
ON facturacion.facturas
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas',
           CAST(d.cod_factura AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_factura = d.cod_factura
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- facturas_detalle ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_insert
ON facturacion.facturas_detalle
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas_detalle',
           CAST(i.cod_detalle AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_detalle = i.cod_detalle
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_update
ON facturacion.facturas_detalle
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas_detalle',
           CAST(i.cod_detalle AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_detalle = i.cod_detalle
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_detalle = i.cod_detalle
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_delete
ON facturacion.facturas_detalle
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.facturas_detalle',
           CAST(d.cod_detalle AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_detalle = d.cod_detalle
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO

/* ---------------------------- notas_credito_debito ---------------------------- */

CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_insert
ON facturacion.notas_credito_debito
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'I',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.notas_credito_debito',
           CAST(i.cod_nota AS VARCHAR(20)),
           (SELECT * FROM inserted x WHERE x.cod_nota = i.cod_nota
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_update
ON facturacion.notas_credito_debito
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'U',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.notas_credito_debito',
           CAST(i.cod_nota AS VARCHAR(20)),
           CONCAT('{"antes":',
                  (SELECT * FROM deleted x WHERE x.cod_nota = i.cod_nota
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  ',"despues":',
                  (SELECT * FROM inserted x WHERE x.cod_nota = i.cod_nota
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
                  '}')
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_delete
ON facturacion.notas_credito_debito
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.bitacora_auditoria
        (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
    SELECT 'D',
           SUSER_SNAME(),
           CAST(SESSION_CONTEXT(N'cod_sesion') AS INT),
           'facturacion.notas_credito_debito',
           CAST(d.cod_nota AS VARCHAR(20)),
           (SELECT * FROM deleted x WHERE x.cod_nota = d.cod_nota
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d;
END;
GO
