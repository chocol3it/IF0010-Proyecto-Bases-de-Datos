/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   12 - Datos de prueba para la optimización (REQ 009)
   -------------------------------------------------------------
   Carga un volumen realista para que los planes de ejecución y
   los índices se puedan medir:
     clientes              1 000  (datos sensibles cifrados)
     productos_servicios   1 000
     facturas              3 000  (fechas repartidas en 2 años)
     facturas_detalle     ~6 000  (1 a 3 líneas por factura)
     notas_credito_debito  1 000
     bitacora_acceso       1 000
     bitacora_auditoria   20 000  (historial de 2 años)
   Los catálogos y los tipos de impuesto no se multiplican: son
   valores reales y fijos (no existen 1 000 monedas o tarifas).

   Durante la carga se desactivan los triggers de auditoría para
   no llenar la bitácora con miles de inserciones de prueba; la
   bitácora recibe su propio historial de prueba al final.
   Se ejecuta una sola vez (si ya hay datos de prueba, no hace nada).
   ============================================================= */
USE PropiFacturacion_AAMM;
GO
SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM facturacion.clientes WHERE nom_cliente LIKE 'Cliente de prueba %')
BEGIN
    PRINT 'Los datos de prueba ya estaban cargados; no se hizo nada.';
    SET NOEXEC ON;
END;
GO

DISABLE TRIGGER ALL ON facturacion.clientes;
DISABLE TRIGGER ALL ON facturacion.productos_servicios;
DISABLE TRIGGER ALL ON facturacion.facturas;
DISABLE TRIGGER ALL ON facturacion.facturas_detalle;
DISABLE TRIGGER ALL ON facturacion.notas_credito_debito;
GO

/* ------------------------- Clientes ------------------------- */
OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

WITH numeros AS (
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO facturacion.clientes
    (nom_cliente, cod_tipo_identificacion, num_identificacion, cod_hash_identificacion,
     des_provincia, des_canton, des_distrito, des_barrio, des_profesion, des_actividad_economica,
     des_correo, num_telefono, fec_registro, cod_estado)
SELECT CONCAT('Cliente de prueba ', i),
       (i % 5) + 1,
       ENCRYPTBYKEY(KEY_GUID('llave_clientes'), x.identificacion),
       HASHBYTES('SHA2_256', x.identificacion),
       CHOOSE((i % 7) + 1, 'San José', 'Alajuela', 'Cartago', 'Heredia', 'Guanacaste', 'Puntarenas', 'Limón'),
       CONCAT('Cantón ', (i % 20) + 1),
       CONCAT('Distrito ', (i % 8) + 1),
       CONCAT('Barrio ', (i % 30) + 1),
       CHOOSE((i % 4) + 1, 'Ingeniería', 'Administración', 'Derecho', 'Comercio'),
       CHOOSE((i % 4) + 1, 'Bienes raíces', 'Construcción', 'Servicios profesionales', 'Comercio'),
       ENCRYPTBYKEY(KEY_GUID('llave_clientes'), CONCAT('cliente', i, '@correo.com')),
       ENCRYPTBYKEY(KEY_GUID('llave_clientes'), CONCAT('8', RIGHT(CONCAT('0000000', i), 7))),
       DATEADD(DAY, -(i % 730), GETDATE()),
       CASE WHEN i % 10 = 0 THEN 'I' ELSE 'A' END
FROM numeros
CROSS APPLY (SELECT CONCAT('9', RIGHT(CONCAT('00000000', i), 8)) AS identificacion) x;

CLOSE SYMMETRIC KEY llave_clientes;
GO

/* ------------------------- Productos ------------------------- */
WITH numeros AS (
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO facturacion.productos_servicios
    (cod_cabys, des_producto, cod_unidad_medida, mon_precio, cod_tipo_impuesto, cod_estado)
SELECT CONCAT('99', RIGHT(CONCAT('00000000000', i), 11)),
       CONCAT('Servicio inmobiliario de prueba ', i),
       (i % 4) + 1,
       ((i % 50) + 1) * 10000,
       (SELECT TOP 1 cod_tipo_impuesto FROM facturacion.tipos_impuesto
        ORDER BY ABS(CHECKSUM(i, cod_tipo_impuesto))),
       CASE WHEN i % 20 = 0 THEN 'I' ELSE 'A' END
FROM numeros;
GO

/* ------------------------- Facturas y detalle ------------------------- */
-- Clientes y productos activos numerados, para repartirlos entre las facturas
SELECT ROW_NUMBER() OVER (ORDER BY cod_cliente) AS rn, cod_cliente
INTO #clientes FROM facturacion.clientes WHERE cod_estado = 'A';
SELECT ROW_NUMBER() OVER (ORDER BY cod_producto) AS rn, p.cod_producto, p.mon_precio, t.por_impuesto
INTO #productos
FROM facturacion.productos_servicios p
JOIN facturacion.tipos_impuesto t ON t.cod_tipo_impuesto = p.cod_tipo_impuesto
WHERE p.cod_estado = 'A';

DECLARE @ultima INT = ISNULL((SELECT MAX(cod_factura) FROM facturacion.facturas), 0);
DECLARE @cant_clientes INT = (SELECT COUNT(*) FROM #clientes);
DECLARE @cant_productos INT = (SELECT COUNT(*) FROM #productos);

WITH numeros AS (
    SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO facturacion.facturas
    (cod_cliente, fec_factura, cod_condicion_venta, cod_medio_pago, cod_moneda, mon_tipo_cambio, des_observaciones)
SELECT c.cod_cliente,
       DATEADD(MINUTE, -((i * 347) % (730 * 1440)), GETDATE()),
       (i % 2) + 1,
       (i % 6) + 1,
       CASE WHEN i % 10 = 0 THEN 2 ELSE 1 END,
       CASE WHEN i % 10 = 0 THEN 505 ELSE 1 END,
       'Factura de prueba'
FROM numeros
JOIN #clientes c ON c.rn = ((i * 7) % @cant_clientes) + 1;

-- 1 a 3 líneas por factura
INSERT INTO facturacion.facturas_detalle
    (cod_factura, cod_producto, can_cantidad, mon_precio_unitario, mon_impuesto, mon_linea)
SELECT f.cod_factura, p.cod_producto, l.j,
       p.mon_precio,
       ROUND(l.j * p.mon_precio * p.por_impuesto / 100, 2),
       l.j * p.mon_precio
FROM facturacion.facturas f
CROSS JOIN (VALUES (1), (2), (3)) l(j)
JOIN #productos p ON p.rn = ((f.cod_factura * 13 + l.j * 101) % @cant_productos) + 1
WHERE f.cod_factura > @ultima
  AND l.j <= (f.cod_factura % 3) + 1;

-- Totales calculados desde el detalle, igual que en pa_facturas_insertar
UPDATE f
SET mon_subtotal        = x.subtotal,
    mon_total_impuestos = x.impuestos,
    mon_total           = x.subtotal + x.impuestos
FROM facturacion.facturas f
CROSS APPLY (SELECT SUM(mon_linea) AS subtotal, SUM(mon_impuesto) AS impuestos
             FROM facturacion.facturas_detalle d
             WHERE d.cod_factura = f.cod_factura) x
WHERE f.cod_factura > @ultima;

/* ------------------------- Notas ------------------------- */
-- Una nota para una de cada tres facturas nuevas (5 % del total)
INSERT INTO facturacion.notas_credito_debito (fec_nota, cod_factura, cod_tipo_nota, des_motivo, mon_nota)
SELECT TOP (1000)
       DATEADD(DAY, 5, f.fec_factura), f.cod_factura,
       (f.cod_factura % 2) + 1,
       CASE WHEN f.cod_factura % 2 = 0 THEN 'Ajuste de precio' ELSE 'Descuento aplicado' END,
       ROUND(f.mon_total * 0.05, 2)
FROM facturacion.facturas f
WHERE f.cod_factura > @ultima AND f.cod_factura % 3 = 0
ORDER BY f.cod_factura;

DROP TABLE #clientes, #productos;
GO

/* ------------------------- Bitácoras ------------------------- */
WITH numeros AS (
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO auditoria.bitacora_acceso (nom_usuario, nom_terminal, des_direccion_ip, fec_ingreso, fec_salida)
SELECT CHOOSE((i % 3) + 1, 'propi_admin', 'propi_digitador', 'propi_consulta'),
       CONCAT('PC-PROPI-', RIGHT(CONCAT('0', (i % 12) + 1), 2)),
       CONCAT('192.168.1.', (i % 200) + 10),
       x.ingreso,
       DATEADD(MINUTE, 30 + (i % 240), x.ingreso)
FROM numeros
CROSS APPLY (SELECT DATEADD(MINUTE, -((i * 631) % (730 * 1440)), GETDATE()) AS ingreso) x;

WITH numeros AS (
    SELECT TOP (20000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO auditoria.bitacora_auditoria
    (fec_registro, ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT DATEADD(MINUTE, -((i * 53) % (730 * 1440)), GETDATE()),
       CHOOSE((i % 3) + 1, 'I', 'U', 'D'),
       CHOOSE((i % 3) + 1, 'propi_admin', 'propi_digitador', 'propi_consulta'),
       (i % 1000) + 1,
       CHOOSE((i % 5) + 1, 'facturacion.clientes', 'facturacion.facturas', 'facturacion.facturas_detalle',
              'facturacion.notas_credito_debito', 'facturacion.productos_servicios'),
       CAST(i AS VARCHAR(20)),
       CONCAT('{"prueba":true,"registro":', i, '}')
FROM numeros;
GO

ENABLE TRIGGER ALL ON facturacion.clientes;
ENABLE TRIGGER ALL ON facturacion.productos_servicios;
ENABLE TRIGGER ALL ON facturacion.facturas;
ENABLE TRIGGER ALL ON facturacion.facturas_detalle;
ENABLE TRIGGER ALL ON facturacion.notas_credito_debito;
GO

SET NOEXEC OFF;
GO

-- Cantidad de registros por tabla
SELECT s.name + '.' + t.name AS tabla, SUM(p.rows) AS registros
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY registros DESC;
GO
