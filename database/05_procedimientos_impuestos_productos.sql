/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   05 - Procedimientos almacenados: Tipos de impuesto y
        Productos/Servicios (REQ 002)
   -------------------------------------------------------------
   Mismo patrón que clientes: TRY/CATCH + transacción explícita.
   Errores: 50001 duplicado, 50002 inexistente, 50003 regla de negocio.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ======================= TIPOS DE IMPUESTO ======================= */

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_impuesto_consultar
    @cod_tipo_impuesto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cod_tipo_impuesto, cod_tarifa, des_tipo_impuesto, por_impuesto, cod_estado
    FROM facturacion.tipos_impuesto
    WHERE @cod_tipo_impuesto IS NULL OR cod_tipo_impuesto = @cod_tipo_impuesto
    ORDER BY cod_tarifa;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_impuesto_insertar
    @cod_tarifa        VARCHAR(2),
    @des_tipo_impuesto VARCHAR(100),
    @por_impuesto      DECIMAL(5,2),
    @cod_estado        CHAR(1) = 'A'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_tipo_impuesto INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM facturacion.tipos_impuesto WHERE cod_tarifa = @cod_tarifa)
            THROW 50001, 'Ya existe un tipo de impuesto con ese código de tarifa.', 1;

        INSERT INTO facturacion.tipos_impuesto (cod_tarifa, des_tipo_impuesto, por_impuesto, cod_estado)
        VALUES (@cod_tarifa, @des_tipo_impuesto, @por_impuesto, @cod_estado);

        SET @cod_tipo_impuesto = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_tipos_impuesto_consultar @cod_tipo_impuesto;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_impuesto_actualizar
    @cod_tipo_impuesto INT,
    @cod_tarifa        VARCHAR(2),
    @des_tipo_impuesto VARCHAR(100),
    @por_impuesto      DECIMAL(5,2),
    @cod_estado        CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.tipos_impuesto WHERE cod_tipo_impuesto = @cod_tipo_impuesto)
            THROW 50002, 'El tipo de impuesto no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.tipos_impuesto
                   WHERE cod_tarifa = @cod_tarifa AND cod_tipo_impuesto <> @cod_tipo_impuesto)
            THROW 50001, 'Ya existe un tipo de impuesto con ese código de tarifa.', 1;

        UPDATE facturacion.tipos_impuesto
        SET cod_tarifa        = @cod_tarifa,
            des_tipo_impuesto = @des_tipo_impuesto,
            por_impuesto      = @por_impuesto,
            cod_estado        = @cod_estado
        WHERE cod_tipo_impuesto = @cod_tipo_impuesto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_tipos_impuesto_consultar @cod_tipo_impuesto;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_impuesto_eliminar
    @cod_tipo_impuesto INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.tipos_impuesto WHERE cod_tipo_impuesto = @cod_tipo_impuesto)
            THROW 50002, 'El tipo de impuesto no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.productos_servicios WHERE cod_tipo_impuesto = @cod_tipo_impuesto)
            THROW 50003, 'El tipo de impuesto está asignado a productos; inactívelo en lugar de borrarlo.', 1;

        DELETE FROM facturacion.tipos_impuesto WHERE cod_tipo_impuesto = @cod_tipo_impuesto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ======================= PRODUCTOS / SERVICIOS ======================= */

CREATE OR ALTER PROCEDURE facturacion.pa_productos_consultar
    @cod_producto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.cod_producto, p.cod_cabys, p.des_producto,
           p.cod_unidad_medida, u.des_unidad_medida,
           p.mon_precio,
           p.cod_tipo_impuesto, t.des_tipo_impuesto, t.por_impuesto,
           p.cod_estado
    FROM facturacion.productos_servicios p
    JOIN facturacion.unidades_medida u ON u.cod_unidad_medida = p.cod_unidad_medida
    JOIN facturacion.tipos_impuesto t ON t.cod_tipo_impuesto = p.cod_tipo_impuesto
    WHERE @cod_producto IS NULL OR p.cod_producto = @cod_producto
    ORDER BY p.des_producto;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_productos_insertar
    @cod_cabys         VARCHAR(13),
    @des_producto      VARCHAR(200),
    @cod_unidad_medida INT,
    @mon_precio        DECIMAL(18,2),
    @cod_tipo_impuesto INT,
    @cod_estado        CHAR(1) = 'A'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_producto INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM facturacion.productos_servicios WHERE cod_cabys = @cod_cabys)
            THROW 50001, 'Ya existe un producto con ese código CABYS.', 1;

        INSERT INTO facturacion.productos_servicios
            (cod_cabys, des_producto, cod_unidad_medida, mon_precio, cod_tipo_impuesto, cod_estado)
        VALUES
            (@cod_cabys, @des_producto, @cod_unidad_medida, @mon_precio, @cod_tipo_impuesto, @cod_estado);

        SET @cod_producto = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_productos_consultar @cod_producto;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_productos_actualizar
    @cod_producto      INT,
    @cod_cabys         VARCHAR(13),
    @des_producto      VARCHAR(200),
    @cod_unidad_medida INT,
    @mon_precio        DECIMAL(18,2),
    @cod_tipo_impuesto INT,
    @cod_estado        CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.productos_servicios WHERE cod_producto = @cod_producto)
            THROW 50002, 'El producto no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.productos_servicios
                   WHERE cod_cabys = @cod_cabys AND cod_producto <> @cod_producto)
            THROW 50001, 'Ya existe un producto con ese código CABYS.', 1;

        -- Las facturas ya emitidas no cambian: guardan el precio del día de la venta
        UPDATE facturacion.productos_servicios
        SET cod_cabys         = @cod_cabys,
            des_producto      = @des_producto,
            cod_unidad_medida = @cod_unidad_medida,
            mon_precio        = @mon_precio,
            cod_tipo_impuesto = @cod_tipo_impuesto,
            cod_estado        = @cod_estado
        WHERE cod_producto = @cod_producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC facturacion.pa_productos_consultar @cod_producto;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_productos_eliminar
    @cod_producto INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.productos_servicios WHERE cod_producto = @cod_producto)
            THROW 50002, 'El producto no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.facturas_detalle WHERE cod_producto = @cod_producto)
            THROW 50003, 'El producto aparece en facturas; inactívelo en lugar de borrarlo.', 1;

        DELETE FROM facturacion.productos_servicios WHERE cod_producto = @cod_producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
