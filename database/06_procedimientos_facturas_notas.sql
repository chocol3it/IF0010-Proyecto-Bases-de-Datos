/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   06 - Procedimientos almacenados: Facturas, detalle y
        Notas de crédito/débito (REQ 002)
   -------------------------------------------------------------
   La factura y todas sus líneas se registran en UNA sola
   transacción: si una línea falla, no queda ni la factura ni
   ninguna línea (atomicidad). Los montos los calcula el SP con el
   precio y el impuesto vigentes del producto; la aplicación solo
   envía el producto y la cantidad.
   Errores: 50001 duplicado, 50002 inexistente, 50003 regla de negocio.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ============================ FACTURAS ============================ */

CREATE OR ALTER PROCEDURE facturacion.pa_facturas_consultar
    @cod_factura INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT f.cod_factura, f.cod_cliente, c.nom_cliente, f.fec_factura,
           f.cod_condicion_venta, cv.des_condicion_venta,
           f.cod_medio_pago, mp.des_medio_pago,
           f.cod_moneda, m.cod_iso,
           f.mon_tipo_cambio, f.des_observaciones,
           f.mon_subtotal, f.mon_total_impuestos, f.mon_total
    FROM facturacion.facturas f
    JOIN facturacion.clientes c           ON c.cod_cliente = f.cod_cliente
    JOIN facturacion.condiciones_venta cv ON cv.cod_condicion_venta = f.cod_condicion_venta
    JOIN facturacion.medios_pago mp       ON mp.cod_medio_pago = f.cod_medio_pago
    JOIN facturacion.monedas m            ON m.cod_moneda = f.cod_moneda
    WHERE @cod_factura IS NULL OR f.cod_factura = @cod_factura
    ORDER BY f.cod_factura DESC;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_facturas_detalle_consultar
    @cod_factura INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.cod_detalle, d.cod_factura, d.cod_producto, p.cod_cabys, p.des_producto,
           d.can_cantidad, d.mon_precio_unitario, d.mon_impuesto, d.mon_linea
    FROM facturacion.facturas_detalle d
    JOIN facturacion.productos_servicios p ON p.cod_producto = d.cod_producto
    WHERE d.cod_factura = @cod_factura
    ORDER BY d.cod_detalle;
END;
GO

/* ---------------------------------------------------------------
   pa_facturas_insertar
   @detalle: líneas en formato JSON, por ejemplo
     [{"codProducto":1,"canCantidad":2},{"codProducto":3,"canCantidad":1}]
   Por cada línea:
     mon_linea    = cantidad * precio
     mon_impuesto = mon_linea * porcentaje de impuesto / 100
   Encabezado:
     subtotal = SUM(mon_linea), impuestos = SUM(mon_impuesto),
     total    = subtotal + impuestos
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_facturas_insertar
    @cod_cliente         INT,
    @cod_condicion_venta INT,
    @cod_medio_pago      INT,
    @cod_moneda          INT,
    @mon_tipo_cambio     DECIMAL(18,4),
    @des_observaciones   VARCHAR(500),
    @detalle             NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_factura INT;

    -- Las líneas del JSON se pasan a una tabla variable para usarlas varias veces
    DECLARE @lineas TABLE (cod_producto INT, can_cantidad DECIMAL(18,2));

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes
                       WHERE cod_cliente = @cod_cliente AND cod_estado = 'A')
            THROW 50003, 'El cliente no existe o está inactivo.', 1;

        IF ISJSON(@detalle) = 0
            THROW 50003, 'El detalle de la factura no es válido.', 1;

        INSERT INTO @lineas (cod_producto, can_cantidad)
        SELECT cod_producto, can_cantidad
        FROM OPENJSON(@detalle)
             WITH (cod_producto INT '$.codProducto', can_cantidad DECIMAL(18,2) '$.canCantidad');

        IF NOT EXISTS (SELECT 1 FROM @lineas)
            THROW 50003, 'La factura debe tener al menos una línea.', 1;

        IF EXISTS (SELECT 1 FROM @lineas l
                   LEFT JOIN facturacion.productos_servicios p
                          ON p.cod_producto = l.cod_producto AND p.cod_estado = 'A'
                   WHERE p.cod_producto IS NULL OR l.can_cantidad IS NULL OR l.can_cantidad <= 0)
            THROW 50003, 'Hay líneas con productos inexistentes o inactivos, o con cantidades inválidas.', 1;

        INSERT INTO facturacion.facturas
            (cod_cliente, cod_condicion_venta, cod_medio_pago, cod_moneda, mon_tipo_cambio, des_observaciones)
        VALUES
            (@cod_cliente, @cod_condicion_venta, @cod_medio_pago, @cod_moneda, @mon_tipo_cambio, @des_observaciones);

        SET @cod_factura = SCOPE_IDENTITY();

        INSERT INTO facturacion.facturas_detalle
            (cod_factura, cod_producto, can_cantidad, mon_precio_unitario, mon_impuesto, mon_linea)
        SELECT @cod_factura, p.cod_producto, l.can_cantidad, p.mon_precio,
               ROUND(l.can_cantidad * p.mon_precio * t.por_impuesto / 100, 2),
               ROUND(l.can_cantidad * p.mon_precio, 2)
        FROM @lineas l
        JOIN facturacion.productos_servicios p ON p.cod_producto = l.cod_producto
        JOIN facturacion.tipos_impuesto t      ON t.cod_tipo_impuesto = p.cod_tipo_impuesto;

        UPDATE f
        SET mon_subtotal        = x.subtotal,
            mon_total_impuestos = x.impuestos,
            mon_total           = x.subtotal + x.impuestos
        FROM facturacion.facturas f
        CROSS APPLY (SELECT SUM(mon_linea) AS subtotal, SUM(mon_impuesto) AS impuestos
                     FROM facturacion.facturas_detalle
                     WHERE cod_factura = @cod_factura) x
        WHERE f.cod_factura = @cod_factura;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_facturas_consultar @cod_factura;
END;
GO

/* ---------------------------------------------------------------
   pa_facturas_actualizar
   Solo se modifican datos que no afectan montos (condición de
   venta, medio de pago y observaciones). Los montos de una factura
   emitida se corrigen con notas de crédito/débito.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_facturas_actualizar
    @cod_factura         INT,
    @cod_condicion_venta INT,
    @cod_medio_pago      INT,
    @des_observaciones   VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.facturas WHERE cod_factura = @cod_factura)
            THROW 50002, 'La factura no existe.', 1;

        UPDATE facturacion.facturas
        SET cod_condicion_venta = @cod_condicion_venta,
            cod_medio_pago      = @cod_medio_pago,
            des_observaciones   = @des_observaciones
        WHERE cod_factura = @cod_factura;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_facturas_consultar @cod_factura;
END;
GO

/* ---------------------------------------------------------------
   pa_facturas_eliminar
   Borra la factura con su detalle (en la misma transacción).
   Error 50003: la factura tiene notas de crédito/débito.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_facturas_eliminar
    @cod_factura INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.facturas WHERE cod_factura = @cod_factura)
            THROW 50002, 'La factura no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.notas_credito_debito WHERE cod_factura = @cod_factura)
            THROW 50003, 'La factura tiene notas de crédito/débito; no se puede borrar.', 1;

        DELETE FROM facturacion.facturas_detalle WHERE cod_factura = @cod_factura;
        DELETE FROM facturacion.facturas WHERE cod_factura = @cod_factura;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ===================== NOTAS DE CRÉDITO / DÉBITO ===================== */

CREATE OR ALTER PROCEDURE facturacion.pa_notas_consultar
    @cod_nota    INT = NULL,
    @cod_factura INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT n.cod_nota, n.fec_nota, n.cod_factura, n.cod_tipo_nota, t.des_tipo_nota,
           n.des_motivo, n.mon_nota
    FROM facturacion.notas_credito_debito n
    JOIN facturacion.tipos_nota t ON t.cod_tipo_nota = n.cod_tipo_nota
    WHERE (@cod_nota IS NULL OR n.cod_nota = @cod_nota)
      AND (@cod_factura IS NULL OR n.cod_factura = @cod_factura)
    ORDER BY n.cod_nota DESC;
END;
GO

/* ---------------------------------------------------------------
   Regla de negocio de las notas de crédito: la suma de todas las
   notas de crédito de una factura no puede superar su total.
   (cod_tipo_nota 1 = Crédito, según 02_catalogos.sql)
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_notas_insertar
    @cod_factura   INT,
    @cod_tipo_nota INT,
    @des_motivo    VARCHAR(300),
    @mon_nota      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_nota INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.facturas WHERE cod_factura = @cod_factura)
            THROW 50002, 'La factura no existe.', 1;

        IF @cod_tipo_nota = 1
           AND (SELECT ISNULL(SUM(mon_nota), 0) FROM facturacion.notas_credito_debito
                WHERE cod_factura = @cod_factura AND cod_tipo_nota = 1) + @mon_nota
               > (SELECT mon_total FROM facturacion.facturas WHERE cod_factura = @cod_factura)
            THROW 50003, 'Las notas de crédito no pueden superar el total de la factura.', 1;

        INSERT INTO facturacion.notas_credito_debito (cod_factura, cod_tipo_nota, des_motivo, mon_nota)
        VALUES (@cod_factura, @cod_tipo_nota, @des_motivo, @mon_nota);

        SET @cod_nota = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_notas_consultar @cod_nota;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_notas_actualizar
    @cod_nota      INT,
    @cod_tipo_nota INT,
    @des_motivo    VARCHAR(300),
    @mon_nota      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_factura INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @cod_factura = cod_factura FROM facturacion.notas_credito_debito WHERE cod_nota = @cod_nota;

        IF @cod_factura IS NULL
            THROW 50002, 'La nota no existe.', 1;

        IF @cod_tipo_nota = 1
           AND (SELECT ISNULL(SUM(mon_nota), 0) FROM facturacion.notas_credito_debito
                WHERE cod_factura = @cod_factura AND cod_tipo_nota = 1 AND cod_nota <> @cod_nota) + @mon_nota
               > (SELECT mon_total FROM facturacion.facturas WHERE cod_factura = @cod_factura)
            THROW 50003, 'Las notas de crédito no pueden superar el total de la factura.', 1;

        UPDATE facturacion.notas_credito_debito
        SET cod_tipo_nota = @cod_tipo_nota,
            des_motivo    = @des_motivo,
            mon_nota      = @mon_nota
        WHERE cod_nota = @cod_nota;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_notas_consultar @cod_nota;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_notas_eliminar
    @cod_nota INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.notas_credito_debito WHERE cod_nota = @cod_nota)
            THROW 50002, 'La nota no existe.', 1;

        DELETE FROM facturacion.notas_credito_debito WHERE cod_nota = @cod_nota;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
