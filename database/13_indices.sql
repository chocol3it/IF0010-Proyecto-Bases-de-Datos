/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   13 - Índices de optimización (REQ 009)
   -------------------------------------------------------------
   Las llaves primarias ya son índices CLUSTERED y las restricciones
   UNIQUE ya crean índices NONCLUSTERED. Estos índices atienden los
   filtros y las búsquedas de los procedimientos que, sin ellos,
   recorren la tabla completa (scan). La justificación y las
   métricas de antes y después se obtienen con 14_medicion_rendimiento.sql.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

-- La bitácora de auditoría no tiene llave primaria (es un heap).
-- CLUSTERED por fecha: el reporte de pistas de auditoría filtra por rango
-- de fec_registro y las filas llegan en orden de fecha, así que las
-- inserciones siempre van al final del índice.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_bitacora_auditoria_fec_registro')
    CREATE CLUSTERED INDEX IX_bitacora_auditoria_fec_registro
        ON auditoria.bitacora_auditoria (fec_registro)
        ON FG_AUDITORIA;

-- Reporte de clientes: filtra por rango de fecha de registro y por estado
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_clientes_fec_registro')
    CREATE NONCLUSTERED INDEX IX_clientes_fec_registro
        ON facturacion.clientes (fec_registro)
        INCLUDE (cod_estado);

-- Reporte de facturas: filtra por rango de fecha. INCLUDE con las columnas
-- que devuelve, así el reporte no tiene que volver a la tabla (índice de cobertura).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_fec_factura')
    CREATE NONCLUSTERED INDEX IX_facturas_fec_factura
        ON facturacion.facturas (fec_factura)
        INCLUDE (cod_cliente, mon_subtotal, mon_total_impuestos, mon_total);

-- Llave foránea hacia clientes: pa_clientes_eliminar revisa si el cliente tiene facturas
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_cod_cliente')
    CREATE NONCLUSTERED INDEX IX_facturas_cod_cliente
        ON facturacion.facturas (cod_cliente);

-- Detalle de una factura (pa_facturas_detalle_consultar y el cálculo de totales)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_detalle_cod_factura')
    CREATE NONCLUSTERED INDEX IX_facturas_detalle_cod_factura
        ON facturacion.facturas_detalle (cod_factura)
        INCLUDE (cod_producto, can_cantidad, mon_precio_unitario, mon_impuesto, mon_linea);

-- Llave foránea hacia productos: pa_productos_eliminar revisa si el producto se facturó
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_detalle_cod_producto')
    CREATE NONCLUSTERED INDEX IX_facturas_detalle_cod_producto
        ON facturacion.facturas_detalle (cod_producto);

-- Notas de una factura: consulta por factura y suma de notas de crédito
-- (pa_notas_insertar, pa_notas_actualizar, pa_facturas_eliminar)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notas_cod_factura')
    CREATE NONCLUSTERED INDEX IX_notas_cod_factura
        ON facturacion.notas_credito_debito (cod_factura)
        INCLUDE (cod_tipo_nota, mon_nota);

-- Llave foránea hacia tipos de impuesto: pa_tipos_impuesto_eliminar
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_productos_cod_tipo_impuesto')
    CREATE NONCLUSTERED INDEX IX_productos_cod_tipo_impuesto
        ON facturacion.productos_servicios (cod_tipo_impuesto);
GO
