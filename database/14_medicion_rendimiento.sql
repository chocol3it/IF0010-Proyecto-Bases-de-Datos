/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   14 - Medición de rendimiento de los procedimientos (REQ 009)
   -------------------------------------------------------------
   Herramienta para obtener el cuadro de antes y después:
     auditoria.pa_medir_rendimiento 'ANTES' | 'DESPUES'
       Ejecuta cada procedimiento almacenado varias veces y guarda,
       por prueba: tiempo promedio (ms), CPU promedio (ms), lecturas
       lógicas promedio y los operadores de su plan de ejecución
       (Table Scan, Index Seek, Key Lookup, etc.).
     auditoria.v_comparacion_rendimiento
       Pone lado a lado la medición ANTES y la DESPUES.

   Cómo se usa (conectado con un login sysadmin, ej. Windows):
     1. Sin índices:   EXEC auditoria.pa_medir_rendimiento 'ANTES';
     2. Ejecutar 13_indices.sql
     3. Con índices:   EXEC auditoria.pa_medir_rendimiento 'DESPUES';
     4. SELECT * FROM auditoria.v_comparacion_rendimiento;
   En SSMS conviene activar Consulta > Opciones de consulta >
   Resultados > Cuadrícula > "Descartar resultados después de la
   ejecución" en la ventana de los pasos 1 y 3: cada procedimiento
   devuelve sus filas y serían cientos de resultados.

   Las pruebas de escritura (insertar, actualizar, eliminar) se
   ejecutan dentro de una transacción que se revierte: miden el costo
   sin cambiar los datos. Las de "eliminar en uso" terminan en el
   error de negocio 50003 a propósito: miden la validación.
   pa_acceso_ingresar no se mide: necesita la conexión de un usuario
   con rol y aquí se ejecuta como administrador del servidor.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

IF OBJECT_ID('auditoria.medicion_rendimiento') IS NULL
    CREATE TABLE auditoria.medicion_rendimiento (
        cod_medicion          INT IDENTITY(1,1) NOT NULL,
        des_fase              VARCHAR(10)       NOT NULL,
        des_prueba            VARCHAR(100)      NOT NULL,
        nom_procedimiento     VARCHAR(128)      NOT NULL,
        can_ejecuciones       INT               NOT NULL,
        num_ms_promedio       DECIMAL(12,3)     NOT NULL,
        num_cpu_ms_promedio   DECIMAL(12,3)     NOT NULL,
        num_lecturas_promedio DECIMAL(14,1)     NOT NULL,
        des_plan              VARCHAR(MAX)      NULL,
        fec_medicion          DATETIME          NOT NULL CONSTRAINT DF_medicion_fecha DEFAULT GETDATE(),
        CONSTRAINT PK_medicion_rendimiento PRIMARY KEY (cod_medicion),
        CONSTRAINT CK_medicion_fase CHECK (des_fase IN ('ANTES', 'DESPUES'))
    ) ON FG_AUDITORIA TEXTIMAGE_ON FG_AUDITORIA;
GO

CREATE OR ALTER PROCEDURE auditoria.pa_medir_rendimiento
    @des_fase        VARCHAR(10),
    @can_ejecuciones INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    /* Valores reales de la base para los parámetros de las pruebas */
    DECLARE @cliente INT = (SELECT MIN(cod_cliente) FROM facturacion.clientes);
    DECLARE @cliente_con_facturas INT = (SELECT TOP 1 cod_cliente FROM facturacion.facturas ORDER BY cod_factura);
    DECLARE @tipo_impuesto INT = (SELECT TOP 1 cod_tipo_impuesto FROM facturacion.productos_servicios ORDER BY cod_producto);
    DECLARE @producto INT = (SELECT TOP 1 cod_producto FROM facturacion.facturas_detalle ORDER BY cod_detalle);
    DECLARE @factura INT = (SELECT MAX(cod_factura) FROM facturacion.facturas);
    DECLARE @factura_con_notas INT = (SELECT TOP 1 cod_factura FROM facturacion.notas_credito_debito ORDER BY cod_nota);
    DECLARE @nota INT = (SELECT MIN(cod_nota) FROM facturacion.notas_credito_debito);
    DECLARE @acceso INT = (SELECT MAX(cod_acceso) FROM auditoria.bitacora_acceso);
    DECLARE @desde NVARCHAR(10) = CONVERT(NVARCHAR(10), DATEADD(DAY, -30, GETDATE()), 23);
    DECLARE @hasta NVARCHAR(10) = CONVERT(NVARCHAR(10), GETDATE(), 23);

    DECLARE @pruebas TABLE (n INT IDENTITY(1,1), prueba VARCHAR(100), procedimiento VARCHAR(128),
                            sentencia NVARCHAR(MAX), escritura BIT);
    INSERT INTO @pruebas (prueba, procedimiento, sentencia, escritura) VALUES
    ('Clientes: listar todos',          'pa_clientes_consultar',    N'EXEC facturacion.pa_clientes_consultar', 0),
    ('Clientes: consultar uno',         'pa_clientes_consultar',    CONCAT(N'EXEC facturacion.pa_clientes_consultar ', @cliente), 0),
    ('Clientes: insertar',              'pa_clientes_insertar',     N'EXEC facturacion.pa_clientes_insertar ''Prueba rendimiento'', 1, ''777777777'', ''San José'', ''Central'', ''Carmen'', NULL, NULL, NULL, ''p@correo.com'', ''8000-0000''', 1),
    ('Clientes: actualizar',            'pa_clientes_actualizar',   CONCAT(N'EXEC facturacion.pa_clientes_actualizar ', @cliente, N', ''Prueba rendimiento'', 1, ''777777778'', ''San José'', ''Central'', ''Carmen'', NULL, NULL, NULL, ''p@correo.com'', ''8000-0000'', ''A'''), 1),
    ('Clientes: eliminar con facturas', 'pa_clientes_eliminar',     CONCAT(N'EXEC facturacion.pa_clientes_eliminar ', @cliente_con_facturas), 1),
    ('Impuestos: listar todos',         'pa_tipos_impuesto_consultar', N'EXEC facturacion.pa_tipos_impuesto_consultar', 0),
    ('Impuestos: insertar',             'pa_tipos_impuesto_insertar',  N'EXEC facturacion.pa_tipos_impuesto_insertar ''99'', ''Prueba'', 5, ''A''', 1),
    ('Impuestos: actualizar',           'pa_tipos_impuesto_actualizar', CONCAT(N'EXEC facturacion.pa_tipos_impuesto_actualizar ', @tipo_impuesto, N', ''98'', ''Prueba'', 5, ''A'''), 1),
    ('Impuestos: eliminar en uso',      'pa_tipos_impuesto_eliminar',  CONCAT(N'EXEC facturacion.pa_tipos_impuesto_eliminar ', @tipo_impuesto), 1),
    ('Productos: listar todos',         'pa_productos_consultar',   N'EXEC facturacion.pa_productos_consultar', 0),
    ('Productos: consultar uno',        'pa_productos_consultar',   CONCAT(N'EXEC facturacion.pa_productos_consultar ', @producto), 0),
    ('Productos: insertar',             'pa_productos_insertar',    N'EXEC facturacion.pa_productos_insertar ''8888888888888'', ''Prueba'', 1, 1000, 1, ''A''', 1),
    ('Productos: actualizar',           'pa_productos_actualizar',  CONCAT(N'EXEC facturacion.pa_productos_actualizar ', @producto, N', ''8888888888887'', ''Prueba'', 1, 1000, 1, ''A'''), 1),
    ('Productos: eliminar facturado',   'pa_productos_eliminar',    CONCAT(N'EXEC facturacion.pa_productos_eliminar ', @producto), 1),
    ('Facturas: listar todas',          'pa_facturas_consultar',    N'EXEC facturacion.pa_facturas_consultar', 0),
    ('Facturas: consultar una',         'pa_facturas_consultar',    CONCAT(N'EXEC facturacion.pa_facturas_consultar ', @factura), 0),
    ('Facturas: detalle de una',        'pa_facturas_detalle_consultar', CONCAT(N'EXEC facturacion.pa_facturas_detalle_consultar ', @factura), 0),
    ('Facturas: insertar con 2 líneas', 'pa_facturas_insertar',     CONCAT(N'EXEC facturacion.pa_facturas_insertar ', @cliente, N', 1, 1, 1, 1, ''Prueba'', N''[{"codProducto":', @producto, N',"canCantidad":1},{"codProducto":', @producto, N',"canCantidad":2}]'''), 1),
    ('Facturas: actualizar',            'pa_facturas_actualizar',   CONCAT(N'EXEC facturacion.pa_facturas_actualizar ', @factura, N', 1, 2, ''Prueba'''), 1),
    ('Facturas: eliminar con notas',    'pa_facturas_eliminar',     CONCAT(N'EXEC facturacion.pa_facturas_eliminar ', @factura_con_notas), 1),
    ('Notas: listar todas',             'pa_notas_consultar',       N'EXEC facturacion.pa_notas_consultar', 0),
    ('Notas: de una factura',           'pa_notas_consultar',       CONCAT(N'EXEC facturacion.pa_notas_consultar NULL, ', @factura_con_notas), 0),
    ('Notas: insertar',                 'pa_notas_insertar',        CONCAT(N'EXEC facturacion.pa_notas_insertar ', @factura_con_notas, N', 1, ''Prueba'', 1'), 1),
    ('Notas: actualizar',               'pa_notas_actualizar',      CONCAT(N'EXEC facturacion.pa_notas_actualizar ', @nota, N', 1, ''Prueba'', 1'), 1),
    ('Notas: eliminar',                 'pa_notas_eliminar',        CONCAT(N'EXEC facturacion.pa_notas_eliminar ', @nota), 1),
    ('Catálogo: estados',               'pa_estados_listar',        N'EXEC facturacion.pa_estados_listar', 0),
    ('Catálogo: tipos de identificación', 'pa_tipos_identificacion_listar', N'EXEC facturacion.pa_tipos_identificacion_listar', 0),
    ('Catálogo: condiciones de venta',  'pa_condiciones_venta_listar', N'EXEC facturacion.pa_condiciones_venta_listar', 0),
    ('Catálogo: medios de pago',        'pa_medios_pago_listar',    N'EXEC facturacion.pa_medios_pago_listar', 0),
    ('Catálogo: monedas',               'pa_monedas_listar',        N'EXEC facturacion.pa_monedas_listar', 0),
    ('Catálogo: unidades de medida',    'pa_unidades_medida_listar', N'EXEC facturacion.pa_unidades_medida_listar', 0),
    ('Catálogo: tipos de nota',         'pa_tipos_nota_listar',     N'EXEC facturacion.pa_tipos_nota_listar', 0),
    ('Acceso: registrar salida',        'pa_acceso_salir',          CONCAT(N'EXEC auditoria.pa_acceso_salir ', @acceso), 1),
    ('Reporte: clientes (30 días)',     'pa_rpt_clientes',          CONCAT(N'EXEC facturacion.pa_rpt_clientes ''', @desde, N''', ''', @hasta, N''', NULL'), 0),
    ('Reporte: facturas (30 días)',     'pa_rpt_facturas',          CONCAT(N'EXEC facturacion.pa_rpt_facturas ''', @desde, N''', ''', @hasta, N''''), 0),
    ('Reporte: auditoría (30 días)',    'pa_rpt_auditoria',         CONCAT(N'EXEC facturacion.pa_rpt_auditoria ''', @desde, N''', ''', @hasta, N''', NULL'), 0),
    ('Reporte: seguridad',              'pa_rpt_seguridad',         N'EXEC facturacion.pa_rpt_seguridad NULL', 0);

    DELETE FROM auditoria.medicion_rendimiento WHERE des_fase = @des_fase;

    -- Se borran los planes guardados para que cada procedimiento se compile
    -- con los índices que existen en este momento
    DBCC FREEPROCCACHE WITH NO_INFOMSGS;

    DECLARE @i INT = 1, @total INT = (SELECT COUNT(*) FROM @pruebas), @k INT;
    DECLARE @sentencia NVARCHAR(MAX), @escritura BIT;
    DECLARE @inicio DATETIME2, @lecturas0 BIGINT, @cpu0 INT;
    DECLARE @microsegundos BIGINT, @lecturas BIGINT, @cpu BIGINT;

    WHILE @i <= @total
    BEGIN
        SELECT @sentencia = sentencia, @escritura = escritura FROM @pruebas WHERE n = @i;
        SELECT @microsegundos = 0, @lecturas = 0, @cpu = 0, @k = 0;

        -- La vuelta 0 es de calentamiento (compila el plan y sube las páginas a memoria): no se cuenta
        WHILE @k <= @can_ejecuciones
        BEGIN
            SELECT @lecturas0 = logical_reads, @cpu0 = cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID;
            SET @inicio = SYSDATETIME();

            BEGIN TRY
                IF @escritura = 1 BEGIN TRANSACTION;
                EXEC sp_executesql @sentencia;
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            END CATCH;

            IF @k > 0
                SELECT @microsegundos += DATEDIFF(MICROSECOND, @inicio, SYSDATETIME()),
                       @lecturas += logical_reads - @lecturas0,
                       @cpu += cpu_time - @cpu0
                FROM sys.dm_exec_requests WHERE session_id = @@SPID;
            SET @k += 1;
        END;

        INSERT INTO auditoria.medicion_rendimiento
            (des_fase, des_prueba, nom_procedimiento, can_ejecuciones, num_ms_promedio, num_cpu_ms_promedio, num_lecturas_promedio)
        SELECT @des_fase, prueba, procedimiento, @can_ejecuciones,
               @microsegundos / 1000.0 / @can_ejecuciones,
               @cpu * 1.0 / @can_ejecuciones,
               @lecturas * 1.0 / @can_ejecuciones
        FROM @pruebas WHERE n = @i;

        SET @i += 1;
    END;

    /* Operadores del plan de ejecución de cada procedimiento, tomados de la caché de planes.
       Ej.: "Clustered Index Scan facturas.PK_facturas, Index Seek facturas.IX_facturas_fec_factura" */
    WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
    operadores AS (
        SELECT DISTINCT OBJECT_NAME(ps.object_id) AS procedimiento,
               CONCAT(r.value('@PhysicalOp', 'VARCHAR(60)'), ' ',
                      REPLACE(REPLACE(r.value('(*/Object/@Table)[1]', 'VARCHAR(128)'), '[', ''), ']', ''),
                      ISNULL('.' + REPLACE(REPLACE(r.value('(*/Object/@Index)[1]', 'VARCHAR(128)'), '[', ''), ']', ''), '')) AS operador
        FROM sys.dm_exec_procedure_stats ps
        CROSS APPLY sys.dm_exec_query_plan(ps.plan_handle) qp
        CROSS APPLY qp.query_plan.nodes('//RelOp') n(r)
        WHERE ps.database_id = DB_ID()
          AND r.exist('*/Object[@Table]') = 1
          AND r.value('(*/Object/@Table)[1]', 'VARCHAR(128)') NOT LIKE '%#%'
          AND r.value('(*/Object/@Table)[1]', 'VARCHAR(128)') NOT LIKE '%@%'
    )
    UPDATE m
    SET des_plan = (SELECT STRING_AGG(o.operador, ', ') WITHIN GROUP (ORDER BY o.operador)
                    FROM operadores o WHERE o.procedimiento = m.nom_procedimiento)
    FROM auditoria.medicion_rendimiento m
    WHERE m.des_fase = @des_fase;

    SELECT des_prueba, num_ms_promedio, num_cpu_ms_promedio, num_lecturas_promedio, des_plan
    FROM auditoria.medicion_rendimiento
    WHERE des_fase = @des_fase
    ORDER BY cod_medicion;
END;
GO

CREATE OR ALTER VIEW auditoria.v_comparacion_rendimiento
AS
SELECT a.des_prueba,
       a.nom_procedimiento,
       a.num_ms_promedio       AS ms_antes,
       d.num_ms_promedio       AS ms_despues,
       a.num_lecturas_promedio AS lecturas_antes,
       d.num_lecturas_promedio AS lecturas_despues,
       CASE WHEN a.num_lecturas_promedio > 0
            THEN CAST(100.0 * (a.num_lecturas_promedio - d.num_lecturas_promedio) / a.num_lecturas_promedio AS DECIMAL(6,1))
       END AS reduccion_lecturas_pct,
       a.des_plan AS plan_antes,
       d.des_plan AS plan_despues
FROM auditoria.medicion_rendimiento a
JOIN auditoria.medicion_rendimiento d ON d.des_prueba = a.des_prueba AND d.des_fase = 'DESPUES'
WHERE a.des_fase = 'ANTES';
GO
