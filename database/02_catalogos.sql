/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   02 - Datos de los catálogos
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

INSERT INTO facturacion.estados (cod_estado, des_estado)
VALUES ('A', 'Activo'), ('I', 'Inactivo');

INSERT INTO facturacion.tipos_identificacion (des_tipo_identificacion)
VALUES ('Cédula física'), ('Cédula jurídica'), ('DIMEX'), ('NITE'), ('Pasaporte');

INSERT INTO facturacion.condiciones_venta (des_condicion_venta)
VALUES ('Contado'), ('Crédito');

INSERT INTO facturacion.medios_pago (des_medio_pago)
VALUES ('Efectivo'), ('Tarjeta'), ('Cheque'), ('Transferencia'), ('SINPE Móvil'), ('Otros');

INSERT INTO facturacion.monedas (cod_iso, des_moneda)
VALUES ('CRC', 'Colón costarricense'), ('USD', 'Dólar estadounidense');

INSERT INTO facturacion.unidades_medida (des_unidad_medida)
VALUES ('Unidad'), ('Servicio'), ('Metro cuadrado'), ('Hectárea');

INSERT INTO facturacion.tipos_nota (des_tipo_nota)
VALUES ('Crédito'), ('Débito');

INSERT INTO facturacion.tipos_impuesto (cod_tarifa, des_tipo_impuesto, por_impuesto)
VALUES ('01', 'Tarifa 0% (exento)', 0),
       ('02', 'Tarifa reducida 1%', 1),
       ('04', 'Tarifa reducida 4%', 4),
       ('08', 'Tarifa general 13%', 13);
GO
