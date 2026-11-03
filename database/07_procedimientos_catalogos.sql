/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   07 - Procedimientos almacenados: listas de catálogos
   -------------------------------------------------------------
   Los formularios de la aplicación usan estas listas para llenar
   sus selectores. Los catálogos se mantienen desde los scripts.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_estados_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_estado, des_estado
    FROM facturacion.estados
    ORDER BY cod_estado;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_identificacion_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_tipo_identificacion, des_tipo_identificacion
    FROM facturacion.tipos_identificacion
    ORDER BY cod_tipo_identificacion;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_condiciones_venta_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_condicion_venta, des_condicion_venta
    FROM facturacion.condiciones_venta
    ORDER BY cod_condicion_venta;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_medios_pago_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_medio_pago, des_medio_pago
    FROM facturacion.medios_pago
    ORDER BY cod_medio_pago;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_monedas_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_moneda, cod_iso, des_moneda
    FROM facturacion.monedas
    ORDER BY cod_moneda;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_unidades_medida_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_unidad_medida, des_unidad_medida
    FROM facturacion.unidades_medida
    ORDER BY cod_unidad_medida;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_tipos_nota_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_tipo_nota, des_tipo_nota
    FROM facturacion.tipos_nota
    ORDER BY cod_tipo_nota;
END;
GO
