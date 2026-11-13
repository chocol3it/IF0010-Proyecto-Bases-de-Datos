--Proyecto IF0010 - Sistema de Facturación Propi
--15 - Diccionario de datos (REQ 010)
--Guarda la descripción de cada tabla y columna como propiedad extendida (MS_Description)
--y el nombre lógico de cada tabla (NombreLogico). Se puede ejecutar varias veces
--Consultar con: dbo.v_diccionario_tablas, dbo.v_diccionario_columnas y dbo.v_diccionario_restricciones
USE PropiFacturacion_AAMM;
GO
SET NOCOUNT ON;

--Tablas: esquema, tabla, nombre lógico, descripción
DECLARE @tablas TABLE (esquema SYSNAME, tabla SYSNAME, logico NVARCHAR(100), descripcion NVARCHAR(500));
INSERT INTO @tablas VALUES
('facturacion', 'estados', N'Estado', N'Catálogo de estados de un registro (activo o inactivo). Lo usan clientes, productos y tipos de impuesto.'),
('facturacion', 'tipos_identificacion', N'Tipo de identificación', N'Catálogo de tipos de identificación de Hacienda para los clientes.'),
('facturacion', 'condiciones_venta', N'Condición de venta', N'Catálogo de condiciones de venta de una factura (contado o crédito).'),
('facturacion', 'medios_pago', N'Medio de pago', N'Catálogo de medios con los que se paga una factura.'),
('facturacion', 'monedas', N'Moneda', N'Catálogo de monedas en que se emite una factura, con su código ISO 4217.'),
('facturacion', 'unidades_medida', N'Unidad de medida', N'Catálogo de unidades en que se vende un producto o servicio inmobiliario.'),
('facturacion', 'tipos_nota', N'Tipo de nota', N'Catálogo de tipos de nota sobre una factura (crédito o débito).'),
('facturacion', 'clientes', N'Cliente', N'Personas físicas o jurídicas a las que Propi les factura. La identificación, el correo y el teléfono se guardan cifrados con AES-256.'),
('facturacion', 'tipos_impuesto', N'Tipo de impuesto', N'Tarifas del impuesto al valor agregado según los códigos de Hacienda.'),
('facturacion', 'productos_servicios', N'Producto o servicio', N'Productos y servicios inmobiliarios que se facturan, con su código CABYS, precio e impuesto.'),
('facturacion', 'facturas', N'Factura', N'Encabezado de la factura electrónica. Los montos los calcula pa_facturas_insertar a partir del detalle.'),
('facturacion', 'facturas_detalle', N'Línea de factura', N'Líneas de una factura. Guardan el precio y el impuesto del día de la venta.'),
('facturacion', 'notas_credito_debito', N'Nota de crédito o débito', N'Ajustes sobre una factura emitida. Las de crédito no pueden superar el total de la factura.'),
('auditoria', 'bitacora_acceso', N'Bitácora de accesos', N'Registro de cada ingreso y salida de un usuario a la aplicación (REQ 003).'),
('auditoria', 'bitacora_auditoria', N'Bitácora de auditoría', N'Registro de cada inserción, modificación y borrado en las tablas del negocio, escrito por los triggers (REQ 005).'),
('auditoria', 'medicion_rendimiento', N'Medición de rendimiento', N'Resultados de pa_medir_rendimiento: métricas de los procedimientos antes y después de los índices (REQ 009).');

--Columnas: esquema, tabla, columna, descripción
DECLARE @columnas TABLE (esquema SYSNAME, tabla SYSNAME, columna SYSNAME, descripcion NVARCHAR(500));
INSERT INTO @columnas VALUES
('facturacion', 'estados', 'cod_estado', N'Código del estado: A = Activo, I = Inactivo.'),
('facturacion', 'estados', 'des_estado', N'Nombre del estado.'),
('facturacion', 'tipos_identificacion', 'cod_tipo_identificacion', N'Código consecutivo del tipo de identificación.'),
('facturacion', 'tipos_identificacion', 'des_tipo_identificacion', N'Nombre del tipo de identificación (cédula física, jurídica, DIMEX, NITE, pasaporte).'),
('facturacion', 'condiciones_venta', 'cod_condicion_venta', N'Código consecutivo de la condición de venta.'),
('facturacion', 'condiciones_venta', 'des_condicion_venta', N'Nombre de la condición de venta.'),
('facturacion', 'medios_pago', 'cod_medio_pago', N'Código consecutivo del medio de pago.'),
('facturacion', 'medios_pago', 'des_medio_pago', N'Nombre del medio de pago.'),
('facturacion', 'monedas', 'cod_moneda', N'Código consecutivo de la moneda.'),
('facturacion', 'monedas', 'cod_iso', N'Código ISO 4217 de tres letras (CRC, USD).'),
('facturacion', 'monedas', 'des_moneda', N'Nombre de la moneda.'),
('facturacion', 'unidades_medida', 'cod_unidad_medida', N'Código consecutivo de la unidad de medida.'),
('facturacion', 'unidades_medida', 'des_unidad_medida', N'Nombre de la unidad de medida.'),
('facturacion', 'tipos_nota', 'cod_tipo_nota', N'Código consecutivo del tipo de nota: 1 = Crédito, 2 = Débito.'),
('facturacion', 'tipos_nota', 'des_tipo_nota', N'Nombre del tipo de nota.'),
('facturacion', 'clientes', 'cod_cliente', N'Código consecutivo del cliente.'),
('facturacion', 'clientes', 'nom_cliente', N'Nombre completo o razón social del cliente.'),
('facturacion', 'clientes', 'cod_tipo_identificacion', N'Tipo de identificación del cliente.'),
('facturacion', 'clientes', 'num_identificacion', N'Número de identificación cifrado con la llave simétrica llave_clientes (AES-256). Dato confidencial.'),
('facturacion', 'clientes', 'cod_hash_identificacion', N'Hash SHA2_256 de la identificación. Permite validar que no se repita, porque el valor cifrado cambia en cada encriptación.'),
('facturacion', 'clientes', 'des_provincia', N'Provincia del domicilio del cliente.'),
('facturacion', 'clientes', 'des_canton', N'Cantón del domicilio del cliente.'),
('facturacion', 'clientes', 'des_distrito', N'Distrito del domicilio del cliente.'),
('facturacion', 'clientes', 'des_barrio', N'Barrio u otras señas del domicilio (opcional).'),
('facturacion', 'clientes', 'des_profesion', N'Profesión del cliente (opcional).'),
('facturacion', 'clientes', 'des_actividad_economica', N'Actividad económica del cliente (opcional).'),
('facturacion', 'clientes', 'des_correo', N'Correo electrónico cifrado con AES-256. Dato confidencial.'),
('facturacion', 'clientes', 'num_telefono', N'Teléfono cifrado con AES-256. Dato confidencial.'),
('facturacion', 'clientes', 'fec_registro', N'Fecha y hora en que se registró el cliente.'),
('facturacion', 'clientes', 'cod_estado', N'Estado del cliente: A = Activo, I = Inactivo.'),
('facturacion', 'tipos_impuesto', 'cod_tipo_impuesto', N'Código consecutivo del tipo de impuesto.'),
('facturacion', 'tipos_impuesto', 'cod_tarifa', N'Código de tarifa de Hacienda (01, 02, 04, 08).'),
('facturacion', 'tipos_impuesto', 'des_tipo_impuesto', N'Nombre de la tarifa.'),
('facturacion', 'tipos_impuesto', 'por_impuesto', N'Porcentaje de impuesto, de 0 a 100.'),
('facturacion', 'tipos_impuesto', 'cod_estado', N'Estado de la tarifa: A = Activo, I = Inactivo.'),
('facturacion', 'productos_servicios', 'cod_producto', N'Código consecutivo del producto o servicio.'),
('facturacion', 'productos_servicios', 'cod_cabys', N'Código CABYS de 13 dígitos del catálogo de bienes y servicios de Hacienda.'),
('facturacion', 'productos_servicios', 'des_producto', N'Descripción del producto o servicio.'),
('facturacion', 'productos_servicios', 'cod_unidad_medida', N'Unidad en que se vende.'),
('facturacion', 'productos_servicios', 'mon_precio', N'Precio unitario vigente, sin impuesto.'),
('facturacion', 'productos_servicios', 'cod_tipo_impuesto', N'Tarifa de impuesto que se le aplica.'),
('facturacion', 'productos_servicios', 'cod_estado', N'Estado del producto: A = Activo, I = Inactivo.'),
('facturacion', 'facturas', 'cod_factura', N'Número consecutivo de la factura.'),
('facturacion', 'facturas', 'cod_cliente', N'Cliente al que se le factura.'),
('facturacion', 'facturas', 'fec_factura', N'Fecha y hora de emisión.'),
('facturacion', 'facturas', 'cod_condicion_venta', N'Condición de venta (contado o crédito).'),
('facturacion', 'facturas', 'cod_medio_pago', N'Medio de pago.'),
('facturacion', 'facturas', 'cod_moneda', N'Moneda de la factura.'),
('facturacion', 'facturas', 'mon_tipo_cambio', N'Tipo de cambio respecto al colón. Es 1 cuando la factura es en colones.'),
('facturacion', 'facturas', 'des_observaciones', N'Observaciones de la factura (opcional).'),
('facturacion', 'facturas', 'mon_subtotal', N'Suma de las líneas sin impuesto. La calcula el procedimiento.'),
('facturacion', 'facturas', 'mon_total_impuestos', N'Suma del impuesto de las líneas. La calcula el procedimiento.'),
('facturacion', 'facturas', 'mon_total', N'Subtotal más impuestos.'),
('facturacion', 'facturas_detalle', 'cod_detalle', N'Código consecutivo de la línea.'),
('facturacion', 'facturas_detalle', 'cod_factura', N'Factura a la que pertenece la línea.'),
('facturacion', 'facturas_detalle', 'cod_producto', N'Producto o servicio facturado.'),
('facturacion', 'facturas_detalle', 'can_cantidad', N'Cantidad vendida, mayor que cero.'),
('facturacion', 'facturas_detalle', 'mon_precio_unitario', N'Precio unitario del día de la venta.'),
('facturacion', 'facturas_detalle', 'mon_impuesto', N'Monto de impuesto de la línea.'),
('facturacion', 'facturas_detalle', 'mon_linea', N'Cantidad por precio unitario, sin impuesto.'),
('facturacion', 'notas_credito_debito', 'cod_nota', N'Código consecutivo de la nota.'),
('facturacion', 'notas_credito_debito', 'fec_nota', N'Fecha y hora de la nota.'),
('facturacion', 'notas_credito_debito', 'cod_factura', N'Factura que se ajusta.'),
('facturacion', 'notas_credito_debito', 'cod_tipo_nota', N'Tipo de nota (crédito o débito).'),
('facturacion', 'notas_credito_debito', 'des_motivo', N'Motivo del ajuste.'),
('facturacion', 'notas_credito_debito', 'mon_nota', N'Monto de la nota, mayor que cero.'),
('auditoria', 'bitacora_acceso', 'cod_acceso', N'Código de la sesión. Se guarda en el JWT y lo usan los triggers como cod_sesion_usuario.'),
('auditoria', 'bitacora_acceso', 'nom_usuario', N'Login de SQL Server del usuario.'),
('auditoria', 'bitacora_acceso', 'nom_terminal', N'Nombre del equipo desde donde ingresó.'),
('auditoria', 'bitacora_acceso', 'des_direccion_ip', N'Dirección IP del cliente.'),
('auditoria', 'bitacora_acceso', 'fec_ingreso', N'Fecha y hora de ingreso.'),
('auditoria', 'bitacora_acceso', 'fec_salida', N'Fecha y hora de salida. Nula mientras la sesión está abierta.'),
('auditoria', 'bitacora_acceso', 'fec_registro', N'Fecha y hora en que se escribió el registro.'),
('auditoria', 'bitacora_auditoria', 'fec_registro', N'Fecha y hora del cambio.'),
('auditoria', 'bitacora_auditoria', 'cod_guid', N'Identificador único del registro de auditoría.'),
('auditoria', 'bitacora_auditoria', 'ind_accion', N'Acción: I = Inserción, U = Modificación, D = Borrado.'),
('auditoria', 'bitacora_auditoria', 'cod_usuario', N'Usuario de base de datos que hizo el cambio.'),
('auditoria', 'bitacora_auditoria', 'cod_sesion_usuario', N'Sesión de la bitácora de accesos en que se hizo el cambio.'),
('auditoria', 'bitacora_auditoria', 'cod_tabla', N'Tabla modificada (esquema.tabla).'),
('auditoria', 'bitacora_auditoria', 'cod_llave', N'Llave primaria del registro modificado.'),
('auditoria', 'bitacora_auditoria', 'des_datos', N'Datos del registro en JSON: los nuevos en inserción y modificación, los anteriores en borrado.'),
('auditoria', 'medicion_rendimiento', 'cod_medicion', N'Código consecutivo de la medición.'),
('auditoria', 'medicion_rendimiento', 'des_fase', N'Fase: ANTES o DESPUES de crear los índices.'),
('auditoria', 'medicion_rendimiento', 'des_prueba', N'Nombre de la prueba.'),
('auditoria', 'medicion_rendimiento', 'nom_procedimiento', N'Procedimiento medido.'),
('auditoria', 'medicion_rendimiento', 'can_ejecuciones', N'Cantidad de ejecuciones promediadas.'),
('auditoria', 'medicion_rendimiento', 'num_ms_promedio', N'Tiempo promedio en milisegundos.'),
('auditoria', 'medicion_rendimiento', 'num_cpu_ms_promedio', N'Tiempo de CPU promedio en milisegundos.'),
('auditoria', 'medicion_rendimiento', 'num_lecturas_promedio', N'Lecturas lógicas promedio (páginas de 8 KB).'),
('auditoria', 'medicion_rendimiento', 'des_plan', N'Operadores del plan de ejecución.'),
('auditoria', 'medicion_rendimiento', 'fec_medicion', N'Fecha y hora de la medición.');

--Se guardan las propiedades (agrega o actualiza)
DECLARE @e SYSNAME, @t SYSNAME, @c SYSNAME, @d NVARCHAR(500), @l NVARCHAR(100);

DECLARE ct CURSOR LOCAL FAST_FORWARD FOR
    SELECT esquema, tabla, logico, descripcion FROM @tablas WHERE OBJECT_ID(esquema + '.' + tabla) IS NOT NULL;
OPEN ct;
FETCH NEXT FROM ct INTO @e, @t, @l, @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id = OBJECT_ID(@e + '.' + @t) AND minor_id = 0 AND name = 'MS_Description')
        EXEC sp_updateextendedproperty 'MS_Description', @d, 'SCHEMA', @e, 'TABLE', @t;
    ELSE
        EXEC sp_addextendedproperty 'MS_Description', @d, 'SCHEMA', @e, 'TABLE', @t;

    IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id = OBJECT_ID(@e + '.' + @t) AND minor_id = 0 AND name = 'NombreLogico')
        EXEC sp_updateextendedproperty 'NombreLogico', @l, 'SCHEMA', @e, 'TABLE', @t;
    ELSE
        EXEC sp_addextendedproperty 'NombreLogico', @l, 'SCHEMA', @e, 'TABLE', @t;
    FETCH NEXT FROM ct INTO @e, @t, @l, @d;
END;
CLOSE ct;
DEALLOCATE ct;

DECLARE cc CURSOR LOCAL FAST_FORWARD FOR
    SELECT esquema, tabla, columna, descripcion FROM @columnas WHERE COL_LENGTH(esquema + '.' + tabla, columna) IS NOT NULL;
OPEN cc;
FETCH NEXT FROM cc INTO @e, @t, @c, @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.extended_properties
               WHERE major_id = OBJECT_ID(@e + '.' + @t) AND minor_id = COLUMNPROPERTY(OBJECT_ID(@e + '.' + @t), @c, 'ColumnId')
                 AND name = 'MS_Description')
        EXEC sp_updateextendedproperty 'MS_Description', @d, 'SCHEMA', @e, 'TABLE', @t, 'COLUMN', @c;
    ELSE
        EXEC sp_addextendedproperty 'MS_Description', @d, 'SCHEMA', @e, 'TABLE', @t, 'COLUMN', @c;
    FETCH NEXT FROM cc INTO @e, @t, @c, @d;
END;
CLOSE cc;
DEALLOCATE cc;
GO

--Diccionario a nivel de tabla
CREATE OR ALTER VIEW dbo.v_diccionario_tablas
AS
SELECT s.name AS esquema,
       t.name AS nombre_fisico,
       CAST(nl.value AS NVARCHAR(100)) AS nombre_logico,
       CAST(ds.value AS NVARCHAR(500)) AS descripcion,
       fg.name AS filegroup,
       (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = t.object_id AND p.index_id IN (0, 1)) AS filas
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id IN (0, 1)
JOIN sys.filegroups fg ON fg.data_space_id = i.data_space_id
LEFT JOIN sys.extended_properties nl ON nl.major_id = t.object_id AND nl.minor_id = 0 AND nl.name = 'NombreLogico'
LEFT JOIN sys.extended_properties ds ON ds.major_id = t.object_id AND ds.minor_id = 0 AND ds.name = 'MS_Description'
WHERE s.name IN ('facturacion', 'auditoria');
GO

--Diccionario a nivel de columna
CREATE OR ALTER VIEW dbo.v_diccionario_columnas
AS
SELECT s.name AS esquema,
       t.name AS tabla,
       c.column_id AS orden,
       c.name AS columna,
       ty.name + CASE
           WHEN ty.name IN ('varchar', 'char', 'varbinary', 'binary')
               THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(10)) END + ')'
           WHEN ty.name IN ('nvarchar', 'nchar')
               THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(10)) END + ')'
           WHEN ty.name IN ('decimal', 'numeric')
               THEN '(' + CAST(c.precision AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
           ELSE '' END AS tipo_dato,
       CASE WHEN c.is_nullable = 1 THEN 'Sí' ELSE 'No' END AS admite_nulos,
       CASE WHEN c.is_identity = 1 THEN 'IDENTITY(1,1)' ELSE dc.definition END AS valor_defecto,
       STUFF(CONCAT((SELECT ', ' + CASE k.type WHEN 'PK' THEN 'PK' ELSE 'UQ' END
                     FROM sys.key_constraints k
                     JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
                     WHERE k.parent_object_id = t.object_id AND ic.column_id = c.column_id
                     FOR XML PATH('')),
                    (SELECT TOP 1 N', FK → ' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id)
                     FROM sys.foreign_key_columns fk
                     WHERE fk.parent_object_id = t.object_id AND fk.parent_column_id = c.column_id)), 1, 2, '') AS llaves,
       CAST(ep.value AS NVARCHAR(500)) AS descripcion
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = t.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
WHERE s.name IN ('facturacion', 'auditoria');
GO

--Restricciones: PK, UNIQUE, FK (tabla referenciada), CHECK y DEFAULT
CREATE OR ALTER VIEW dbo.v_diccionario_restricciones
AS
SELECT s.name AS esquema, t.name AS tabla, k.name AS restriccion,
       CASE k.type WHEN 'PK' THEN 'PRIMARY KEY' ELSE 'UNIQUE' END AS tipo,
       STUFF((SELECT ', ' + c.name FROM sys.index_columns ic
              JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
              ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 2, '') AS detalle
FROM sys.key_constraints k
JOIN sys.tables t ON t.object_id = k.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
UNION ALL
SELECT s.name, t.name, f.name, 'FOREIGN KEY',
       STUFF((SELECT ', ' + c.name FROM sys.foreign_key_columns fc
              JOIN sys.columns c ON c.object_id = fc.parent_object_id AND c.column_id = fc.parent_column_id
              WHERE fc.constraint_object_id = f.object_id FOR XML PATH('')), 1, 2, '')
       + N' → ' + OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id)
FROM sys.foreign_keys f
JOIN sys.tables t ON t.object_id = f.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
UNION ALL
SELECT s.name, t.name, ck.name, 'CHECK', ck.definition
FROM sys.check_constraints ck
JOIN sys.tables t ON t.object_id = ck.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
UNION ALL
SELECT s.name, t.name, d.name, 'DEFAULT', COL_NAME(d.parent_object_id, d.parent_column_id) + ' = ' + d.definition
FROM sys.default_constraints d
JOIN sys.tables t ON t.object_id = d.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id;
GO

--Diccionario completo
SELECT * FROM dbo.v_diccionario_tablas ORDER BY esquema DESC, nombre_fisico;
SELECT * FROM dbo.v_diccionario_columnas ORDER BY esquema DESC, tabla, orden;
SELECT * FROM dbo.v_diccionario_restricciones ORDER BY esquema DESC, tabla, tipo, restriccion;
GO
