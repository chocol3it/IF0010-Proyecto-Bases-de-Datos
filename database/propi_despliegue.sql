/* ===========================================================================
   PROYECTO IF0010 - SISTEMA DE FACTURACIÓN PROPI
   SCRIPT DE DESPLIEGUE COMPLETO DE LA BASE DE DATOS PropiFacturacion_AAMM
   Ejecutar completo en SSMS conectado como sysadmin (F5). Crea la base de datos, tablas, catálogos,
   cifrado, procedimientos almacenados, triggers, reportes, índices, diccionario, logins, usuarios,
   roles, permisos, respaldos y sus trabajos programados.

   Contenido
      1. Base de datos y almacenamiento          9. Bitácora de accesos
      2. Tablas, llaves y restricciones         10. Triggers de auditoría
      3. Datos de los catálogos                 11. Reportes
      4. Cifrado columnar                       12. Índices
      5. Procedimientos: clientes               13. Diccionario de datos
      6. Procedimientos: impuestos y productos  14. Seguridad
      7. Procedimientos: facturas y notas       15. Respaldos
      8. Procedimientos: catálogos              16. Programación de respaldos

   Scripts aparte (carpeta anexos): datos de prueba y medición de rendimiento (REQ 009),
   restauración de prueba (REQ 013) y base secundaria con log shipping (REQ 014).
   =========================================================================== */

/* ===========================================================================
   1. BASE DE DATOS Y ALMACENAMIENTO
   Filegroup PRIMARY: tablas del negocio (esquema facturacion).
   Filegroup FG_AUDITORIA: bitácoras (esquema auditoria), en su propio archivo .ndf.
   ALLOW_SNAPSHOT_ISOLATION: lo usan los reportes (REQ 007).
   =========================================================================== */

USE master;
GO

IF DB_ID('PropiFacturacion_AAMM') IS NULL
    CREATE DATABASE PropiFacturacion_AAMM;
GO

USE PropiFacturacion_AAMM;
GO

-- Filegroup para las bitácoras. El archivo .ndf se crea en la misma
-- carpeta del archivo principal (.mdf) de la base de datos.
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = 'FG_AUDITORIA')
BEGIN
    DECLARE @ruta NVARCHAR(260);
    SELECT @ruta = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM sys.database_files
    WHERE file_id = 1;

    ALTER DATABASE PropiFacturacion_AAMM ADD FILEGROUP FG_AUDITORIA;

    EXEC ('ALTER DATABASE PropiFacturacion_AAMM ADD FILE (
               NAME = ''PropiFacturacion_AAMM_auditoria'',
               FILENAME = ''' + @ruta + 'PropiFacturacion_AAMM_auditoria.ndf'',
               SIZE = 8MB,
               FILEGROWTH = 8MB
           ) TO FILEGROUP FG_AUDITORIA');
END;
GO

-- Permite el nivel de aislamiento SNAPSHOT que usan los reportes (REQ 007)
ALTER DATABASE PropiFacturacion_AAMM SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

-- Esquemas: uno para el negocio y otro para las bitácoras
IF SCHEMA_ID('facturacion') IS NULL EXEC ('CREATE SCHEMA facturacion');
GO
IF SCHEMA_ID('auditoria') IS NULL EXEC ('CREATE SCHEMA auditoria');
GO

/* ===========================================================================
   2. TABLAS, LLAVES Y RESTRICCIONES (REQ 001)
   Nomenclatura: cod_ código, num_ número, nom_ nombre, des_ descripción, fec_ fecha,
   ind_ indicador, mon_ monto, can_ cantidad, por_ porcentaje.
   OJO: borra y vuelve a crear las tablas.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

-- Se borran en orden inverso por las llaves foráneas
DROP TABLE IF EXISTS auditoria.bitacora_auditoria;
DROP TABLE IF EXISTS auditoria.bitacora_acceso;
DROP TABLE IF EXISTS facturacion.notas_credito_debito;
DROP TABLE IF EXISTS facturacion.facturas_detalle;
DROP TABLE IF EXISTS facturacion.facturas;
DROP TABLE IF EXISTS facturacion.productos_servicios;
DROP TABLE IF EXISTS facturacion.tipos_impuesto;
DROP TABLE IF EXISTS facturacion.clientes;
DROP TABLE IF EXISTS facturacion.tipos_nota;
DROP TABLE IF EXISTS facturacion.unidades_medida;
DROP TABLE IF EXISTS facturacion.monedas;
DROP TABLE IF EXISTS facturacion.medios_pago;
DROP TABLE IF EXISTS facturacion.condiciones_venta;
DROP TABLE IF EXISTS facturacion.tipos_identificacion;
DROP TABLE IF EXISTS facturacion.estados;
GO

/* ---------------------- Catálogos ---------------------- */

CREATE TABLE facturacion.estados (
    cod_estado CHAR(1)     NOT NULL,
    des_estado VARCHAR(30) NOT NULL,
    CONSTRAINT PK_estados PRIMARY KEY (cod_estado),
    CONSTRAINT UQ_estados_des UNIQUE (des_estado)
);

CREATE TABLE facturacion.tipos_identificacion (
    cod_tipo_identificacion INT IDENTITY(1,1) NOT NULL,
    des_tipo_identificacion VARCHAR(50)       NOT NULL,
    CONSTRAINT PK_tipos_identificacion PRIMARY KEY (cod_tipo_identificacion),
    CONSTRAINT UQ_tipos_identificacion_des UNIQUE (des_tipo_identificacion)
);

CREATE TABLE facturacion.condiciones_venta (
    cod_condicion_venta INT IDENTITY(1,1) NOT NULL,
    des_condicion_venta VARCHAR(30)       NOT NULL,
    CONSTRAINT PK_condiciones_venta PRIMARY KEY (cod_condicion_venta),
    CONSTRAINT UQ_condiciones_venta_des UNIQUE (des_condicion_venta)
);

CREATE TABLE facturacion.medios_pago (
    cod_medio_pago INT IDENTITY(1,1) NOT NULL,
    des_medio_pago VARCHAR(30)       NOT NULL,
    CONSTRAINT PK_medios_pago PRIMARY KEY (cod_medio_pago),
    CONSTRAINT UQ_medios_pago_des UNIQUE (des_medio_pago)
);

CREATE TABLE facturacion.monedas (
    cod_moneda INT IDENTITY(1,1) NOT NULL,
    cod_iso    CHAR(3)           NOT NULL,
    des_moneda VARCHAR(30)       NOT NULL,
    CONSTRAINT PK_monedas PRIMARY KEY (cod_moneda),
    CONSTRAINT UQ_monedas_iso UNIQUE (cod_iso)
);

CREATE TABLE facturacion.unidades_medida (
    cod_unidad_medida INT IDENTITY(1,1) NOT NULL,
    des_unidad_medida VARCHAR(50)       NOT NULL,
    CONSTRAINT PK_unidades_medida PRIMARY KEY (cod_unidad_medida),
    CONSTRAINT UQ_unidades_medida_des UNIQUE (des_unidad_medida)
);

CREATE TABLE facturacion.tipos_nota (
    cod_tipo_nota INT IDENTITY(1,1) NOT NULL,
    des_tipo_nota VARCHAR(30)       NOT NULL,
    CONSTRAINT PK_tipos_nota PRIMARY KEY (cod_tipo_nota),
    CONSTRAINT UQ_tipos_nota_des UNIQUE (des_tipo_nota)
);
GO

/* ---------------------- Entidades ---------------------- */

-- REQ 006: num_identificacion, des_correo y num_telefono se guardan cifrados
-- (VARBINARY) con la llave simétrica llave_clientes (ver propi_despliegue.sql (sección 4)).
-- Como el valor cifrado cambia en cada encriptación, la unicidad de la
-- identificación se controla con su hash SHA2_256 (cod_hash_identificacion).
CREATE TABLE facturacion.clientes (
    cod_cliente             INT IDENTITY(1,1) NOT NULL,
    nom_cliente             VARCHAR(150)      NOT NULL,
    cod_tipo_identificacion INT               NOT NULL,
    num_identificacion      VARBINARY(256)    NOT NULL,
    cod_hash_identificacion VARBINARY(32)     NOT NULL,
    des_provincia           VARCHAR(50)       NOT NULL,
    des_canton              VARCHAR(50)       NOT NULL,
    des_distrito            VARCHAR(50)       NOT NULL,
    des_barrio              VARCHAR(100)      NULL,
    des_profesion           VARCHAR(100)      NULL,
    des_actividad_economica VARCHAR(150)      NULL,
    des_correo              VARBINARY(512)    NOT NULL,
    num_telefono            VARBINARY(256)    NOT NULL,
    fec_registro            DATETIME          NOT NULL CONSTRAINT DF_clientes_fec_registro DEFAULT GETDATE(),
    cod_estado              CHAR(1)           NOT NULL CONSTRAINT DF_clientes_estado DEFAULT 'A',
    CONSTRAINT PK_clientes PRIMARY KEY (cod_cliente),
    CONSTRAINT UQ_clientes_identificacion UNIQUE (cod_tipo_identificacion, cod_hash_identificacion),
    CONSTRAINT FK_clientes_tipos_identificacion FOREIGN KEY (cod_tipo_identificacion)
        REFERENCES facturacion.tipos_identificacion (cod_tipo_identificacion),
    CONSTRAINT FK_clientes_estados FOREIGN KEY (cod_estado)
        REFERENCES facturacion.estados (cod_estado)
);

-- cod_tarifa: código de tarifa de Hacienda (ej. 08); por_impuesto: el porcentaje (ej. 13.00)
CREATE TABLE facturacion.tipos_impuesto (
    cod_tipo_impuesto INT IDENTITY(1,1) NOT NULL,
    cod_tarifa        VARCHAR(2)        NOT NULL,
    des_tipo_impuesto VARCHAR(100)      NOT NULL,
    por_impuesto      DECIMAL(5,2)      NOT NULL,
    cod_estado        CHAR(1)           NOT NULL CONSTRAINT DF_tipos_impuesto_estado DEFAULT 'A',
    CONSTRAINT PK_tipos_impuesto PRIMARY KEY (cod_tipo_impuesto),
    CONSTRAINT UQ_tipos_impuesto_tarifa UNIQUE (cod_tarifa),
    CONSTRAINT CK_tipos_impuesto_porcentaje CHECK (por_impuesto BETWEEN 0 AND 100),
    CONSTRAINT FK_tipos_impuesto_estados FOREIGN KEY (cod_estado)
        REFERENCES facturacion.estados (cod_estado)
);

CREATE TABLE facturacion.productos_servicios (
    cod_producto      INT IDENTITY(1,1) NOT NULL,
    cod_cabys         VARCHAR(13)       NOT NULL,
    des_producto      VARCHAR(200)      NOT NULL,
    cod_unidad_medida INT               NOT NULL,
    mon_precio        DECIMAL(18,2)     NOT NULL,
    cod_tipo_impuesto INT               NOT NULL,
    cod_estado        CHAR(1)           NOT NULL CONSTRAINT DF_productos_estado DEFAULT 'A',
    CONSTRAINT PK_productos_servicios PRIMARY KEY (cod_producto),
    CONSTRAINT UQ_productos_servicios_cabys UNIQUE (cod_cabys),
    CONSTRAINT CK_productos_servicios_precio CHECK (mon_precio >= 0),
    CONSTRAINT FK_productos_unidades_medida FOREIGN KEY (cod_unidad_medida)
        REFERENCES facturacion.unidades_medida (cod_unidad_medida),
    CONSTRAINT FK_productos_tipos_impuesto FOREIGN KEY (cod_tipo_impuesto)
        REFERENCES facturacion.tipos_impuesto (cod_tipo_impuesto),
    CONSTRAINT FK_productos_estados FOREIGN KEY (cod_estado)
        REFERENCES facturacion.estados (cod_estado)
);

-- Los montos los calcula el procedimiento almacenado a partir del detalle
CREATE TABLE facturacion.facturas (
    cod_factura         INT IDENTITY(1,1) NOT NULL,
    cod_cliente         INT               NOT NULL,
    fec_factura         DATETIME          NOT NULL CONSTRAINT DF_facturas_fecha DEFAULT GETDATE(),
    cod_condicion_venta INT               NOT NULL,
    cod_medio_pago      INT               NOT NULL,
    cod_moneda          INT               NOT NULL,
    mon_tipo_cambio     DECIMAL(18,4)     NOT NULL CONSTRAINT DF_facturas_tipo_cambio DEFAULT 1,
    des_observaciones   VARCHAR(500)      NULL,
    mon_subtotal        DECIMAL(18,2)     NOT NULL CONSTRAINT DF_facturas_subtotal DEFAULT 0,
    mon_total_impuestos DECIMAL(18,2)     NOT NULL CONSTRAINT DF_facturas_impuestos DEFAULT 0,
    mon_total           DECIMAL(18,2)     NOT NULL CONSTRAINT DF_facturas_total DEFAULT 0,
    CONSTRAINT PK_facturas PRIMARY KEY (cod_factura),
    CONSTRAINT CK_facturas_tipo_cambio CHECK (mon_tipo_cambio > 0),
    CONSTRAINT CK_facturas_montos CHECK (mon_subtotal >= 0 AND mon_total_impuestos >= 0 AND mon_total >= 0),
    CONSTRAINT FK_facturas_clientes FOREIGN KEY (cod_cliente)
        REFERENCES facturacion.clientes (cod_cliente),
    CONSTRAINT FK_facturas_condiciones_venta FOREIGN KEY (cod_condicion_venta)
        REFERENCES facturacion.condiciones_venta (cod_condicion_venta),
    CONSTRAINT FK_facturas_medios_pago FOREIGN KEY (cod_medio_pago)
        REFERENCES facturacion.medios_pago (cod_medio_pago),
    CONSTRAINT FK_facturas_monedas FOREIGN KEY (cod_moneda)
        REFERENCES facturacion.monedas (cod_moneda)
);

-- mon_precio_unitario y mon_impuesto guardan los valores del día de la venta,
-- así un cambio de precio posterior no altera facturas ya emitidas.
CREATE TABLE facturacion.facturas_detalle (
    cod_detalle         INT IDENTITY(1,1) NOT NULL,
    cod_factura         INT               NOT NULL,
    cod_producto        INT               NOT NULL,
    can_cantidad        DECIMAL(18,2)     NOT NULL,
    mon_precio_unitario DECIMAL(18,2)     NOT NULL,
    mon_impuesto        DECIMAL(18,2)     NOT NULL,
    mon_linea           DECIMAL(18,2)     NOT NULL,
    CONSTRAINT PK_facturas_detalle PRIMARY KEY (cod_detalle),
    CONSTRAINT CK_facturas_detalle_cantidad CHECK (can_cantidad > 0),
    CONSTRAINT CK_facturas_detalle_montos CHECK (mon_precio_unitario >= 0 AND mon_impuesto >= 0 AND mon_linea >= 0),
    CONSTRAINT FK_facturas_detalle_facturas FOREIGN KEY (cod_factura)
        REFERENCES facturacion.facturas (cod_factura),
    CONSTRAINT FK_facturas_detalle_productos FOREIGN KEY (cod_producto)
        REFERENCES facturacion.productos_servicios (cod_producto)
);

CREATE TABLE facturacion.notas_credito_debito (
    cod_nota      INT IDENTITY(1,1) NOT NULL,
    fec_nota      DATETIME          NOT NULL CONSTRAINT DF_notas_fecha DEFAULT GETDATE(),
    cod_factura   INT               NOT NULL,
    cod_tipo_nota INT               NOT NULL,
    des_motivo    VARCHAR(300)      NOT NULL,
    mon_nota      DECIMAL(18,2)     NOT NULL,
    CONSTRAINT PK_notas_credito_debito PRIMARY KEY (cod_nota),
    CONSTRAINT CK_notas_monto CHECK (mon_nota > 0),
    CONSTRAINT FK_notas_facturas FOREIGN KEY (cod_factura)
        REFERENCES facturacion.facturas (cod_factura),
    CONSTRAINT FK_notas_tipos_nota FOREIGN KEY (cod_tipo_nota)
        REFERENCES facturacion.tipos_nota (cod_tipo_nota)
);
GO

/* ---------------------- Bitácoras (filegroup FG_AUDITORIA) ---------------------- */

-- REQ 003: cada ingreso y salida de la aplicación
CREATE TABLE auditoria.bitacora_acceso (
    cod_acceso       INT IDENTITY(1,1) NOT NULL,
    nom_usuario      VARCHAR(128)      NOT NULL,
    nom_terminal     VARCHAR(128)      NULL,
    des_direccion_ip VARCHAR(48)       NULL,
    fec_ingreso      DATETIME          NOT NULL,
    fec_salida       DATETIME          NULL,
    fec_registro     DATETIME          NOT NULL CONSTRAINT DF_bitacora_acceso_registro DEFAULT GETDATE(),
    CONSTRAINT PK_bitacora_acceso PRIMARY KEY (cod_acceso)
) ON FG_AUDITORIA;

-- REQ 005: columnas exactamente como las pide el enunciado
CREATE TABLE auditoria.bitacora_auditoria (
    fec_registro       DATETIME      NOT NULL CONSTRAINT DF_bitacora_auditoria_registro DEFAULT GETDATE(),
    cod_guid           VARCHAR(255)  NULL     CONSTRAINT DF_bitacora_auditoria_guid DEFAULT CONVERT(VARCHAR(255), NEWID()),
    ind_accion         CHAR(1)       NOT NULL,
    cod_usuario        CHAR(128)     NOT NULL,
    cod_sesion_usuario INT           NULL,
    cod_tabla          VARCHAR(255)  NOT NULL,
    cod_llave          VARCHAR(2000) NULL,
    des_datos          VARCHAR(MAX)  NULL,
    CONSTRAINT CK_bitacora_auditoria_accion CHECK (ind_accion IN ('I', 'D', 'U'))
) ON FG_AUDITORIA TEXTIMAGE_ON FG_AUDITORIA;
GO

/* ===========================================================================
   3. DATOS DE LOS CATÁLOGOS
   =========================================================================== */

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

/* ===========================================================================
   4. CIFRADO COLUMNAR DE DATOS SENSIBLES (REQ 006)
   Service Master Key -> Database Master Key -> certificado cert_clientes -> llave llave_clientes (AES_256).
   Respaldar la master key y el certificado (sección 12): sin ellos no se leen los datos cifrados.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Propi#MasterKey2026';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'cert_clientes')
    CREATE CERTIFICATE cert_clientes
        WITH SUBJECT = 'Cifrado de datos sensibles de clientes';
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'llave_clientes')
    CREATE SYMMETRIC KEY llave_clientes
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE cert_clientes;
GO

/* ===========================================================================
   5. PROCEDIMIENTOS ALMACENADOS: CLIENTES (REQ 002 y REQ 006)
   Todo el CRUD pasa por procedimientos con parámetros (evita SQL Injection).
   Los que escriben usan TRY/CATCH y transacción. Errores: 50001 duplicado, 50002 inexistente,
   50003 regla de negocio. Identificación, correo y teléfono se cifran al guardar y se descifran al consultar.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_clientes_consultar
   Devuelve un cliente (@cod_cliente) o todos si se envía NULL.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_consultar
    @cod_cliente INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    SELECT c.cod_cliente, c.nom_cliente, c.cod_tipo_identificacion, t.des_tipo_identificacion,
           CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
           c.des_provincia, c.des_canton, c.des_distrito, c.des_barrio, c.des_profesion,
           c.des_actividad_economica,
           CONVERT(VARCHAR(150), DECRYPTBYKEY(c.des_correo)) AS des_correo,
           CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_telefono)) AS num_telefono,
           c.fec_registro, c.cod_estado
    FROM facturacion.clientes c
    JOIN facturacion.tipos_identificacion t ON t.cod_tipo_identificacion = c.cod_tipo_identificacion
    WHERE @cod_cliente IS NULL OR c.cod_cliente = @cod_cliente
    ORDER BY c.nom_cliente;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_insertar
   Registra un cliente y devuelve el registro creado.
   Error 50001: ya existe un cliente con esa identificación.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_insertar
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion INT,
    @num_identificacion      VARCHAR(20),
    @des_provincia           VARCHAR(50),
    @des_canton              VARCHAR(50),
    @des_distrito            VARCHAR(50),
    @des_barrio              VARCHAR(100),
    @des_profesion           VARCHAR(100),
    @des_actividad_economica VARCHAR(150),
    @des_correo              VARCHAR(150),
    @num_telefono            VARCHAR(20),
    @cod_estado              CHAR(1) = 'A'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_cliente INT;
    DECLARE @hash VARBINARY(32) = HASHBYTES('SHA2_256', @num_identificacion);

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND cod_hash_identificacion = @hash)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        INSERT INTO facturacion.clientes
            (nom_cliente, cod_tipo_identificacion, num_identificacion, cod_hash_identificacion,
             des_provincia, des_canton, des_distrito, des_barrio, des_profesion,
             des_actividad_economica, des_correo, num_telefono, cod_estado)
        VALUES
            (@nom_cliente, @cod_tipo_identificacion,
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_identificacion), @hash,
             @des_provincia, @des_canton, @des_distrito, @des_barrio, @des_profesion,
             @des_actividad_economica,
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @des_correo),
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_telefono),
             @cod_estado);

        SET @cod_cliente = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;

    EXEC facturacion.pa_clientes_consultar @cod_cliente;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_actualizar
   Modifica un cliente y devuelve el registro actualizado.
   Error 50002: el cliente no existe.
   Error 50001: la identificación ya pertenece a otro cliente.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_actualizar
    @cod_cliente             INT,
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion INT,
    @num_identificacion      VARCHAR(20),
    @des_provincia           VARCHAR(50),
    @des_canton              VARCHAR(50),
    @des_distrito            VARCHAR(50),
    @des_barrio              VARCHAR(100),
    @des_profesion           VARCHAR(100),
    @des_actividad_economica VARCHAR(150),
    @des_correo              VARCHAR(150),
    @num_telefono            VARCHAR(20),
    @cod_estado              CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @hash VARBINARY(32) = HASHBYTES('SHA2_256', @num_identificacion);

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes WHERE cod_cliente = @cod_cliente)
            THROW 50002, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND cod_hash_identificacion = @hash
                     AND cod_cliente <> @cod_cliente)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        UPDATE facturacion.clientes
        SET nom_cliente             = @nom_cliente,
            cod_tipo_identificacion = @cod_tipo_identificacion,
            num_identificacion      = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_identificacion),
            cod_hash_identificacion = @hash,
            des_provincia           = @des_provincia,
            des_canton              = @des_canton,
            des_distrito            = @des_distrito,
            des_barrio              = @des_barrio,
            des_profesion           = @des_profesion,
            des_actividad_economica = @des_actividad_economica,
            des_correo              = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @des_correo),
            num_telefono            = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_telefono),
            cod_estado              = @cod_estado
        WHERE cod_cliente = @cod_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;

    EXEC facturacion.pa_clientes_consultar @cod_cliente;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_eliminar
   Borra un cliente.
   Error 50002: el cliente no existe.
   Error 50003: el cliente tiene facturas (se debe inactivar).
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_eliminar
    @cod_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes WHERE cod_cliente = @cod_cliente)
            THROW 50002, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.facturas WHERE cod_cliente = @cod_cliente)
            THROW 50003, 'El cliente tiene facturas registradas; inactívelo en lugar de borrarlo.', 1;

        DELETE FROM facturacion.clientes WHERE cod_cliente = @cod_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ===========================================================================
   6. PROCEDIMIENTOS ALMACENADOS: TIPOS DE IMPUESTO Y PRODUCTOS (REQ 002)
   =========================================================================== */

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

/* ===========================================================================
   7. PROCEDIMIENTOS ALMACENADOS: FACTURAS, DETALLE Y NOTAS (REQ 002)
   La factura y sus líneas se guardan en una sola transacción; los montos los calcula el procedimiento.
   =========================================================================== */

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
   (cod_tipo_nota 1 = Crédito, según propi_despliegue.sql (sección 3))
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

/* ===========================================================================
   8. PROCEDIMIENTOS ALMACENADOS: LISTAS DE CATÁLOGOS
   =========================================================================== */

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

/* ===========================================================================
   9. BITÁCORA DE ACCESOS (REQ 003)
   El backend abre una conexión con el usuario y la contraseña (seguridad de SQL Server) y ejecuta
   pa_acceso_ingresar: obtiene el rol, registra el ingreso y devuelve el código de sesión.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_acceso_ingresar
   Error 50004: el usuario no pertenece a ningún rol de la aplicación.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE auditoria.pa_acceso_ingresar
    @nom_terminal     VARCHAR(128),
    @des_direccion_ip VARCHAR(48)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_acceso INT;
    DECLARE @nom_rol VARCHAR(20);

    -- IS_ROLEMEMBER revisa los roles del usuario conectado
    SET @nom_rol = CASE
        WHEN IS_ROLEMEMBER('rol_administrador') = 1 THEN 'ADMINISTRADOR'
        WHEN IS_ROLEMEMBER('rol_digitador') = 1     THEN 'DIGITADOR'
        WHEN IS_ROLEMEMBER('rol_consulta') = 1      THEN 'CONSULTA'
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @nom_rol IS NULL
            THROW 50004, 'El usuario no tiene un rol asignado en la aplicación.', 1;

        INSERT INTO auditoria.bitacora_acceso (nom_usuario, nom_terminal, des_direccion_ip, fec_ingreso)
        VALUES (SUSER_SNAME(), ISNULL(@nom_terminal, HOST_NAME()), @des_direccion_ip, GETDATE());

        SET @cod_acceso = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @cod_acceso AS cod_acceso, SUSER_SNAME() AS nom_usuario, @nom_rol AS nom_rol;
END;
GO

/* ---------------------------------------------------------------
   pa_acceso_salir
   Registra la fecha y hora de salida de una sesión abierta.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE auditoria.pa_acceso_salir
    @cod_acceso INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE auditoria.bitacora_acceso
        SET fec_salida = GETDATE()
        WHERE cod_acceso = @cod_acceso AND fec_salida IS NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ===========================================================================
   10. TRIGGERS DE AUDITORÍA (REQ 005)
   3 triggers por tabla (INSERT, UPDATE, DELETE). Cada fila afectada genera una fila en la bitácora:
     cod_usuario = SUSER_SNAME(), cod_sesion_usuario = SESSION_CONTEXT('cod_sesion'),
     cod_llave = llave primaria, des_datos = la fila en JSON (en UPDATE, antes y después).
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO
-- estados
CREATE OR ALTER TRIGGER facturacion.tr_estados_insert ON facturacion.estados AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.estados', i.cod_estado, (SELECT * FROM inserted x WHERE x.cod_estado = i.cod_estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_estados_update ON facturacion.estados AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.estados', i.cod_estado,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_estado = i.cod_estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_estado = i.cod_estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_estados_delete ON facturacion.estados AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.estados', d.cod_estado, (SELECT * FROM deleted x WHERE x.cod_estado = d.cod_estado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- tipos_identificacion
CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_insert ON facturacion.tipos_identificacion AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_identificacion', i.cod_tipo_identificacion, (SELECT * FROM inserted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_update ON facturacion.tipos_identificacion AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_identificacion', i.cod_tipo_identificacion,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_tipo_identificacion = i.cod_tipo_identificacion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_identificacion_delete ON facturacion.tipos_identificacion AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_identificacion', d.cod_tipo_identificacion, (SELECT * FROM deleted x WHERE x.cod_tipo_identificacion = d.cod_tipo_identificacion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- condiciones_venta
CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_insert ON facturacion.condiciones_venta AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.condiciones_venta', i.cod_condicion_venta, (SELECT * FROM inserted x WHERE x.cod_condicion_venta = i.cod_condicion_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_update ON facturacion.condiciones_venta AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.condiciones_venta', i.cod_condicion_venta,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_condicion_venta = i.cod_condicion_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_condicion_venta = i.cod_condicion_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_condiciones_venta_delete ON facturacion.condiciones_venta AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.condiciones_venta', d.cod_condicion_venta, (SELECT * FROM deleted x WHERE x.cod_condicion_venta = d.cod_condicion_venta FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- medios_pago
CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_insert ON facturacion.medios_pago AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.medios_pago', i.cod_medio_pago, (SELECT * FROM inserted x WHERE x.cod_medio_pago = i.cod_medio_pago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_update ON facturacion.medios_pago AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.medios_pago', i.cod_medio_pago,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_medio_pago = i.cod_medio_pago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_medio_pago = i.cod_medio_pago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_medios_pago_delete ON facturacion.medios_pago AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.medios_pago', d.cod_medio_pago, (SELECT * FROM deleted x WHERE x.cod_medio_pago = d.cod_medio_pago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- monedas
CREATE OR ALTER TRIGGER facturacion.tr_monedas_insert ON facturacion.monedas AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.monedas', i.cod_moneda, (SELECT * FROM inserted x WHERE x.cod_moneda = i.cod_moneda FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_monedas_update ON facturacion.monedas AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.monedas', i.cod_moneda,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_moneda = i.cod_moneda FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_moneda = i.cod_moneda FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_monedas_delete ON facturacion.monedas AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.monedas', d.cod_moneda, (SELECT * FROM deleted x WHERE x.cod_moneda = d.cod_moneda FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- unidades_medida
CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_insert ON facturacion.unidades_medida AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.unidades_medida', i.cod_unidad_medida, (SELECT * FROM inserted x WHERE x.cod_unidad_medida = i.cod_unidad_medida FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_update ON facturacion.unidades_medida AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.unidades_medida', i.cod_unidad_medida,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_unidad_medida = i.cod_unidad_medida FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_unidad_medida = i.cod_unidad_medida FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_unidades_medida_delete ON facturacion.unidades_medida AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.unidades_medida', d.cod_unidad_medida, (SELECT * FROM deleted x WHERE x.cod_unidad_medida = d.cod_unidad_medida FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- tipos_nota
CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_insert ON facturacion.tipos_nota AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_nota', i.cod_tipo_nota, (SELECT * FROM inserted x WHERE x.cod_tipo_nota = i.cod_tipo_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_update ON facturacion.tipos_nota AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_nota', i.cod_tipo_nota,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_tipo_nota = i.cod_tipo_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_tipo_nota = i.cod_tipo_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_nota_delete ON facturacion.tipos_nota AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_nota', d.cod_tipo_nota, (SELECT * FROM deleted x WHERE x.cod_tipo_nota = d.cod_tipo_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- clientes
CREATE OR ALTER TRIGGER facturacion.tr_clientes_insert ON facturacion.clientes AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.clientes', i.cod_cliente, (SELECT * FROM inserted x WHERE x.cod_cliente = i.cod_cliente FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_clientes_update ON facturacion.clientes AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.clientes', i.cod_cliente,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_cliente = i.cod_cliente FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_cliente = i.cod_cliente FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_clientes_delete ON facturacion.clientes AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.clientes', d.cod_cliente, (SELECT * FROM deleted x WHERE x.cod_cliente = d.cod_cliente FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- tipos_impuesto
CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_insert ON facturacion.tipos_impuesto AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_impuesto', i.cod_tipo_impuesto, (SELECT * FROM inserted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_update ON facturacion.tipos_impuesto AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_impuesto', i.cod_tipo_impuesto,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_tipo_impuesto = i.cod_tipo_impuesto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_tipos_impuesto_delete ON facturacion.tipos_impuesto AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.tipos_impuesto', d.cod_tipo_impuesto, (SELECT * FROM deleted x WHERE x.cod_tipo_impuesto = d.cod_tipo_impuesto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- productos_servicios
CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_insert ON facturacion.productos_servicios AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.productos_servicios', i.cod_producto, (SELECT * FROM inserted x WHERE x.cod_producto = i.cod_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_update ON facturacion.productos_servicios AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.productos_servicios', i.cod_producto,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_producto = i.cod_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_producto = i.cod_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_productos_servicios_delete ON facturacion.productos_servicios AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.productos_servicios', d.cod_producto, (SELECT * FROM deleted x WHERE x.cod_producto = d.cod_producto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- facturas
CREATE OR ALTER TRIGGER facturacion.tr_facturas_insert ON facturacion.facturas AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas', i.cod_factura, (SELECT * FROM inserted x WHERE x.cod_factura = i.cod_factura FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_facturas_update ON facturacion.facturas AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas', i.cod_factura,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_factura = i.cod_factura FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_factura = i.cod_factura FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_facturas_delete ON facturacion.facturas AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas', d.cod_factura, (SELECT * FROM deleted x WHERE x.cod_factura = d.cod_factura FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- facturas_detalle
CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_insert ON facturacion.facturas_detalle AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas_detalle', i.cod_detalle, (SELECT * FROM inserted x WHERE x.cod_detalle = i.cod_detalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_update ON facturacion.facturas_detalle AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas_detalle', i.cod_detalle,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_detalle = i.cod_detalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_detalle = i.cod_detalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_facturas_detalle_delete ON facturacion.facturas_detalle AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.facturas_detalle', d.cod_detalle, (SELECT * FROM deleted x WHERE x.cod_detalle = d.cod_detalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

-- notas_credito_debito
CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_insert ON facturacion.notas_credito_debito AFTER INSERT AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'I', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.notas_credito_debito', i.cod_nota, (SELECT * FROM inserted x WHERE x.cod_nota = i.cod_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_update ON facturacion.notas_credito_debito AFTER UPDATE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'U', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.notas_credito_debito', i.cod_nota,
       CONCAT('{"antes":', (SELECT * FROM deleted x WHERE x.cod_nota = i.cod_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), ',"despues":', (SELECT * FROM inserted x WHERE x.cod_nota = i.cod_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '}')
FROM inserted i;
GO
CREATE OR ALTER TRIGGER facturacion.tr_notas_credito_debito_delete ON facturacion.notas_credito_debito AFTER DELETE AS
SET NOCOUNT ON;
INSERT INTO auditoria.bitacora_auditoria (ind_accion, cod_usuario, cod_sesion_usuario, cod_tabla, cod_llave, des_datos)
SELECT 'D', SUSER_SNAME(), CAST(SESSION_CONTEXT(N'cod_sesion') AS INT), 'facturacion.notas_credito_debito', d.cod_nota, (SELECT * FROM deleted x WHERE x.cod_nota = d.cod_nota FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM deleted d;
GO

/* ===========================================================================
   11. REPORTES (REQ 007)
   Todos usan TRY/CATCH, BEGIN/COMMIT/ROLLBACK y filtran fechas por rango (>= desde y < hasta + 1 día).
   Aislamiento SNAPSHOT: lee una foto consistente de los datos confirmados, no bloquea a quien factura
   ni lo bloquean, y no tiene lecturas sucias. READ UNCOMMITTED permite lecturas sucias; READ COMMITTED
   espera a las escrituras; REPEATABLE READ y SERIALIZABLE bloquean a los digitadores.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_rpt_clientes
   Reporte de clientes resumido.
   @cod_estado: 'A' activos, 'I' inactivos, NULL todos.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_clientes
    @fec_desde  DATE,
    @fec_hasta  DATE,
    @cod_estado CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT c.nom_cliente,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
               c.des_actividad_economica,
               CONVERT(VARCHAR(150), DECRYPTBYKEY(c.des_correo)) AS des_correo,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_telefono)) AS num_telefono
        FROM facturacion.clientes c
        WHERE c.fec_registro >= @fec_desde
          AND c.fec_registro < DATEADD(DAY, 1, @fec_hasta)
          AND (@cod_estado IS NULL OR c.cod_estado = @cod_estado)
        ORDER BY c.nom_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_facturas
   Reporte de facturas por rango de fechas de la factura.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_facturas
    @fec_desde DATE,
    @fec_hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT c.nom_cliente,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
               c.des_actividad_economica,
               f.cod_factura, f.fec_factura,
               f.mon_subtotal, f.mon_total_impuestos, f.mon_total
        FROM facturacion.facturas f
        JOIN facturacion.clientes c ON c.cod_cliente = f.cod_cliente
        WHERE f.fec_factura >= @fec_desde
          AND f.fec_factura < DATEADD(DAY, 1, @fec_hasta)
        ORDER BY f.fec_factura, f.cod_factura;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_auditoria
   Reporte de pistas de auditoría.
   @cod_usuario: un usuario específico o NULL para todos.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_auditoria
    @fec_desde   DATE,
    @fec_hasta   DATE,
    @cod_usuario VARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT b.fec_registro,
               CASE b.ind_accion
                   WHEN 'I' THEN 'Inserción'
                   WHEN 'D' THEN 'Borrado'
                   WHEN 'U' THEN 'Modificación'
               END AS des_accion,
               RTRIM(b.cod_usuario) AS cod_usuario,
               b.cod_tabla,
               b.cod_llave,
               b.des_datos
        FROM auditoria.bitacora_auditoria b
        WHERE b.fec_registro >= @fec_desde
          AND b.fec_registro < DATEADD(DAY, 1, @fec_hasta)
          AND (@cod_usuario IS NULL OR b.cod_usuario = @cod_usuario)
        ORDER BY b.fec_registro DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------
   pa_rpt_seguridad
   Reporte de configuración de seguridad: permisos de cada usuario
   (directos o heredados de su rol) sobre los objetos de la BD.
   @nom_usuario: un usuario específico o NULL para todos.
   WITH EXECUTE AS OWNER: las vistas del sistema solo muestran lo
   que el usuario conectado puede ver; el reporte se ejecuta con
   los permisos del dueño (dbo) para listar la configuración completa.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_rpt_seguridad
    @nom_usuario VARCHAR(128) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT u.name AS nom_usuario,
               ISNULL(r.name, '(sin rol)') AS nom_rol,
               CASE p.class
                   WHEN 1 THEN OBJECT_SCHEMA_NAME(p.major_id) + '.' + OBJECT_NAME(p.major_id)
                   WHEN 3 THEN SCHEMA_NAME(p.major_id)
                   WHEN 4 THEN USER_NAME(p.major_id)
                   WHEN 24 THEN (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = p.major_id)
                   WHEN 25 THEN (SELECT name FROM sys.certificates WHERE certificate_id = p.major_id)
                   ELSE DB_NAME()
               END AS nom_objeto,
               CASE
                   WHEN p.class = 1 THEN
                       CASE o.type
                           WHEN 'U'  THEN 'Tabla'
                           WHEN 'V'  THEN 'Vista'
                           WHEN 'P'  THEN 'Procedimiento'
                           WHEN 'FN' THEN 'Función'
                           WHEN 'IF' THEN 'Función'
                           WHEN 'TF' THEN 'Función'
                           ELSE o.type_desc
                       END
                   WHEN p.class = 3  THEN 'Esquema'
                   WHEN p.class = 4  THEN 'Usuario'
                   WHEN p.class = 24 THEN 'Llave simétrica'
                   WHEN p.class = 25 THEN 'Certificado'
                   ELSE 'Base de datos'
               END AS des_tipo_objeto,
               CASE p.permission_name
                   WHEN 'SELECT'  THEN 'Selección'
                   WHEN 'INSERT'  THEN 'Inserción'
                   WHEN 'DELETE'  THEN 'Borrado'
                   WHEN 'UPDATE'  THEN 'Modificación'
                   WHEN 'EXECUTE' THEN 'Execute'
                   ELSE p.permission_name
               END AS des_permiso,
               p.state_desc AS des_estado_permiso
        FROM sys.database_principals u
        LEFT JOIN sys.database_role_members rm ON rm.member_principal_id = u.principal_id
        LEFT JOIN sys.database_principals r    ON r.principal_id = rm.role_principal_id
        JOIN sys.database_permissions p
             ON p.grantee_principal_id = u.principal_id
             OR p.grantee_principal_id = r.principal_id
        LEFT JOIN sys.objects o ON p.class = 1 AND o.object_id = p.major_id
        WHERE u.type = 'S'
          AND u.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
          AND p.permission_name <> 'CONNECT'
          AND (@nom_usuario IS NULL OR u.name = @nom_usuario)
        ORDER BY u.name, nom_objeto, des_permiso;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ===========================================================================
   12. ÍNDICES (REQ 009)
   Las llaves primarias ya son índices clustered. Estos atienden filtros por fecha y búsquedas por FK.
   =========================================================================== */

USE PropiFacturacion_AAMM;
GO

--La bitácora de auditoría es un heap: clustered por fecha para el reporte de auditoría
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_bitacora_auditoria_fec_registro')
    CREATE CLUSTERED INDEX IX_bitacora_auditoria_fec_registro
        ON auditoria.bitacora_auditoria (fec_registro)
        ON FG_AUDITORIA;

--Reporte de clientes: filtra por fecha de registro y estado
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_clientes_fec_registro')
    CREATE NONCLUSTERED INDEX IX_clientes_fec_registro
        ON facturacion.clientes (fec_registro)
        INCLUDE (cod_estado);

--Reporte de facturas: filtra por fecha; INCLUDE evita volver a la tabla
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_fec_factura')
    CREATE NONCLUSTERED INDEX IX_facturas_fec_factura
        ON facturacion.facturas (fec_factura)
        INCLUDE (cod_cliente, mon_subtotal, mon_total_impuestos, mon_total);

--FK a clientes: pa_clientes_eliminar revisa si el cliente tiene facturas
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_cod_cliente')
    CREATE NONCLUSTERED INDEX IX_facturas_cod_cliente
        ON facturacion.facturas (cod_cliente);

--Detalle de una factura y cálculo de totales
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_detalle_cod_factura')
    CREATE NONCLUSTERED INDEX IX_facturas_detalle_cod_factura
        ON facturacion.facturas_detalle (cod_factura)
        INCLUDE (cod_producto, can_cantidad, mon_precio_unitario, mon_impuesto, mon_linea);

--FK a productos: pa_productos_eliminar revisa si el producto se facturó
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_detalle_cod_producto')
    CREATE NONCLUSTERED INDEX IX_facturas_detalle_cod_producto
        ON facturacion.facturas_detalle (cod_producto);

--Notas de una factura y suma de notas de crédito
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notas_cod_factura')
    CREATE NONCLUSTERED INDEX IX_notas_cod_factura
        ON facturacion.notas_credito_debito (cod_factura)
        INCLUDE (cod_tipo_nota, mon_nota);

--FK a tipos de impuesto: pa_tipos_impuesto_eliminar
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_productos_cod_tipo_impuesto')
    CREATE NONCLUSTERED INDEX IX_productos_cod_tipo_impuesto
        ON facturacion.productos_servicios (cod_tipo_impuesto);
GO

/* ===========================================================================
   13. DICCIONARIO DE DATOS (REQ 010)
   Descripciones como propiedades extendidas. Consultar dbo.v_diccionario_tablas, _columnas y _restricciones.
   =========================================================================== */

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

/* ===========================================================================
   14. SEGURIDAD: LOGINS, USUARIOS, ROLES Y PERMISOS (REQ 003, 004 y 008)
   propi_admin -> rol_administrador (todo); propi_digitador -> rol_digitador (clientes, facturas y notas);
   propi_consulta -> rol_consulta (reportes). propi_app: login del backend, solo puede suplantar
   (IMPERSONATE) a los usuarios; cada petición corre con EXECUTE AS USER y REVERT.
   Las contraseñas son de ejemplo para el ambiente académico.
   =========================================================================== */

USE master;
GO

/* ------------------------- Logins ------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_app')
    CREATE LOGIN propi_app WITH PASSWORD = 'PropiApp#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_admin')
    CREATE LOGIN propi_admin WITH PASSWORD = 'Admin#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_digitador')
    CREATE LOGIN propi_digitador WITH PASSWORD = 'Digitador#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_consulta')
    CREATE LOGIN propi_consulta WITH PASSWORD = 'Consulta#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
GO

USE PropiFacturacion_AAMM;
GO

/* ------------------------- Usuarios ------------------------- */
IF USER_ID('propi_app') IS NULL       CREATE USER propi_app FOR LOGIN propi_app;
IF USER_ID('propi_admin') IS NULL     CREATE USER propi_admin FOR LOGIN propi_admin;
IF USER_ID('propi_digitador') IS NULL CREATE USER propi_digitador FOR LOGIN propi_digitador;
IF USER_ID('propi_consulta') IS NULL  CREATE USER propi_consulta FOR LOGIN propi_consulta;
GO

/* ------------------------- Roles (REQ 004) ------------------------- */
IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL CREATE ROLE rol_administrador;
IF DATABASE_PRINCIPAL_ID('rol_digitador') IS NULL     CREATE ROLE rol_digitador;
IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL      CREATE ROLE rol_consulta;
GO

ALTER ROLE rol_administrador ADD MEMBER propi_admin;
ALTER ROLE rol_digitador     ADD MEMBER propi_digitador;
ALTER ROLE rol_consulta      ADD MEMBER propi_consulta;
GO

/* =================== Permisos (REQ 008) ===================
   1. REVOKE: se limpian los permisos anteriores de los roles
      (REVOKE quita tanto un GRANT como un DENY), así el script
      siempre deja la configuración exacta.
   2. GRANT: se otorga lo que cada rol necesita.
   3. DENY: se niega explícitamente lo que el rol no debe hacer.
      DENY tiene prioridad sobre cualquier GRANT.
   ========================================================== */

/* -------- 1. REVOKE: limpiar -------- */
REVOKE SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::facturacion FROM rol_administrador, rol_digitador, rol_consulta;
REVOKE SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::auditoria   FROM rol_administrador, rol_digitador, rol_consulta;
GO

/* -------- 2. GRANT -------- */

-- Login técnico: solo puede suplantar a los usuarios de la aplicación
GRANT IMPERSONATE ON USER::propi_admin     TO propi_app;
GRANT IMPERSONATE ON USER::propi_digitador TO propi_app;
GRANT IMPERSONATE ON USER::propi_consulta  TO propi_app;

-- Todos los roles: registrar su ingreso y salida (REQ 003)
GRANT EXECUTE ON auditoria.pa_acceso_ingresar TO rol_administrador, rol_digitador, rol_consulta;
GRANT EXECUTE ON auditoria.pa_acceso_salir    TO rol_administrador, rol_digitador, rol_consulta;

-- Todos los roles leen datos cifrados de clientes (REQ 006):
-- para abrir la llave simétrica se necesita ver la llave y
-- controlar el certificado que la protege.
GRANT VIEW DEFINITION ON SYMMETRIC KEY::llave_clientes TO rol_administrador, rol_digitador, rol_consulta;
GRANT CONTROL ON CERTIFICATE::cert_clientes            TO rol_administrador, rol_digitador, rol_consulta;

-- Administrador: acceso full a toda la información
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::facturacion TO rol_administrador;
GRANT SELECT, EXECUTE ON SCHEMA::auditoria TO rol_administrador;

-- Digitador: ingreso de clientes, registro de facturas y notas
GRANT EXECUTE ON facturacion.pa_clientes_consultar         TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_clientes_insertar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_clientes_actualizar        TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_consultar         TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_detalle_consultar TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_insertar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_consultar            TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_insertar             TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_actualizar           TO rol_digitador;
-- para armar las facturas necesita ver productos e impuestos (solo lectura)
GRANT EXECUTE ON facturacion.pa_productos_consultar        TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_impuesto_consultar   TO rol_digitador;
-- listas de los formularios
GRANT EXECUTE ON facturacion.pa_estados_listar              TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_identificacion_listar TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_condiciones_venta_listar    TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_medios_pago_listar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_monedas_listar              TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_nota_listar           TO rol_digitador;

-- Consulta: reportería
GRANT EXECUTE ON facturacion.pa_rpt_clientes  TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_facturas  TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_auditoria TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_seguridad TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_estados_listar TO rol_consulta;
GO

/* -------- 3. DENY -------- */

-- Digitador y consulta nunca tocan las tablas directamente: solo por
-- procedimientos. (Los procedimientos sí pueden leerlas gracias al
-- encadenamiento de propiedad: tabla y procedimiento son de dbo.)
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::facturacion TO rol_digitador, rol_consulta;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::auditoria   TO rol_digitador, rol_consulta;

-- El digitador no puede borrar ni modificar el catálogo de productos e impuestos
DENY EXECUTE ON facturacion.pa_clientes_eliminar         TO rol_digitador;
DENY EXECUTE ON facturacion.pa_facturas_eliminar         TO rol_digitador;
DENY EXECUTE ON facturacion.pa_facturas_actualizar       TO rol_digitador;
DENY EXECUTE ON facturacion.pa_notas_eliminar            TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_insertar        TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_actualizar      TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_eliminar        TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_insertar   TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_actualizar TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_eliminar   TO rol_digitador;

-- El usuario de consulta no puede ejecutar ninguna operación de escritura
DENY EXECUTE ON facturacion.pa_clientes_insertar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_clientes_actualizar TO rol_consulta;
DENY EXECUTE ON facturacion.pa_clientes_eliminar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_facturas_insertar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_facturas_eliminar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_notas_insertar      TO rol_consulta;
DENY EXECUTE ON facturacion.pa_notas_eliminar      TO rol_consulta;
GO

/* ===========================================================================
   15. RESPALDOS (REQ 013)
   Modelo FULL y dbo.pa_respaldar: completo, diferencial, log y llaves de cifrado.
   Requiere la carpeta C:\PropiRespaldos\ con permiso de escritura para el servicio de SQL Server.
   =========================================================================== */

USE master;
GO

--FULL guarda todo el log hasta respaldarlo: permite respaldos de log y restaurar a un punto en el tiempo
ALTER DATABASE PropiFacturacion_AAMM SET RECOVERY FULL;
GO

USE PropiFacturacion_AAMM;
GO

--@tipo: COMPLETO, DIFERENCIAL, LOG o LLAVES
--@ruta: carpeta destino; si es NULL usa la carpeta de respaldos de la instancia
--BACKUP no se puede ejecutar dentro de una transacción, por eso aquí solo hay TRY/CATCH
CREATE OR ALTER PROCEDURE dbo.pa_respaldar
    @tipo              VARCHAR(12),
    @ruta              NVARCHAR(260) = NULL,
    @contrasena_llaves NVARCHAR(128) = NULL,
    @archivo           NVARCHAR(400) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base SYSNAME = DB_NAME();
    DECLARE @sello VARCHAR(30) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss_fff');
    DECLARE @nombre NVARCHAR(128) = CONCAT(@base, ' ', @tipo, ' ', @sello);
    DECLARE @sql NVARCHAR(MAX), @archivo_cert NVARCHAR(400), @archivo_llave NVARCHAR(400);

    IF @ruta IS NULL SET @ruta = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF RIGHT(@ruta, 1) <> '\' SET @ruta += '\';

    BEGIN TRY
        IF @tipo = 'COMPLETO'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_completo_', @sello, '.bak');
            BACKUP DATABASE @base TO DISK = @archivo WITH CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'DIFERENCIAL'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_diferencial_', @sello, '.bak');
            BACKUP DATABASE @base TO DISK = @archivo WITH DIFFERENTIAL, CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'LOG'
        BEGIN
            SET @archivo = CONCAT(@ruta, @base, '_log_', @sello, '.trn');
            BACKUP LOG @base TO DISK = @archivo WITH CHECKSUM, INIT, NAME = @nombre;
        END
        ELSE IF @tipo = 'LLAVES'
        BEGIN
            --Sin la master key y el certificado no se pueden leer los datos cifrados de clientes
            IF @contrasena_llaves IS NULL
                THROW 50003, 'Debe indicar la contraseña con que se protegen los archivos de las llaves.', 1;

            SET @archivo = CONCAT(@ruta, @base, '_master_key_', @sello, '.key');
            SET @archivo_cert = CONCAT(@ruta, @base, '_cert_clientes_', @sello, '.cer');
            SET @archivo_llave = CONCAT(@ruta, @base, '_cert_clientes_', @sello, '.pvk');

            --Estas sentencias solo aceptan textos fijos, por eso se arman con SQL dinámico
            SET @sql = CONCAT(
                N'BACKUP MASTER KEY TO FILE = ''', REPLACE(@archivo, '''', ''''''), N''' ',
                N'ENCRYPTION BY PASSWORD = ''', REPLACE(@contrasena_llaves, '''', ''''''), N''';',
                N'BACKUP CERTIFICATE cert_clientes TO FILE = ''', REPLACE(@archivo_cert, '''', ''''''), N''' ',
                N'WITH PRIVATE KEY (FILE = ''', REPLACE(@archivo_llave, '''', ''''''), N''', ',
                N'ENCRYPTION BY PASSWORD = ''', REPLACE(@contrasena_llaves, '''', ''''''), N''');');
            EXEC sp_executesql @sql;
        END
        ELSE
            THROW 50003, 'Tipo de respaldo inválido. Use COMPLETO, DIFERENCIAL, LOG o LLAVES.', 1;

        --Comprueba que el archivo se pueda leer
        IF @tipo <> 'LLAVES'
            RESTORE VERIFYONLY FROM DISK = @archivo WITH CHECKSUM;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

--Primer juego de respaldos. Cambie la carpeta y la contraseña según el servidor
DECLARE @ruta NVARCHAR(260) = N'C:\PropiRespaldos\';
DECLARE @archivo NVARCHAR(400);

EXEC dbo.pa_respaldar 'LLAVES', @ruta, N'Propi#Llaves2026', @archivo OUTPUT;
PRINT CONCAT('Llaves: ', @archivo);
EXEC dbo.pa_respaldar 'COMPLETO', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Completo: ', @archivo);
EXEC dbo.pa_respaldar 'DIFERENCIAL', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Diferencial: ', @archivo);
EXEC dbo.pa_respaldar 'LOG', @ruta, NULL, @archivo OUTPUT;
PRINT CONCAT('Log: ', @archivo);
GO

--Historial de respaldos de la base
SELECT TOP 10 bs.backup_finish_date,
       CASE bs.type WHEN 'D' THEN 'Completo' WHEN 'I' THEN 'Diferencial' WHEN 'L' THEN 'Log' END AS tipo,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS tamano_mb,
       bmf.physical_device_name AS archivo
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'PropiFacturacion_AAMM'
ORDER BY bs.backup_finish_date DESC;
GO

/* ===========================================================================
   16. PROGRAMACIÓN DE RESPALDOS CON EL AGENTE SQL (REQ 013 y REQ 014)
   Requiere SQL Server Developer o Standard (Express no tiene Agente).
   =========================================================================== */

USE msdb;
GO

DECLARE @ruta NVARCHAR(260) = N'C:\PropiRespaldos\';
DECLARE @base SYSNAME = N'PropiFacturacion_AAMM';
DECLARE @trabajos TABLE (n INT IDENTITY, nombre SYSNAME, comando NVARCHAR(MAX),
                         freq_type INT, freq_interval INT, subday_type INT, subday_interval INT, hora INT);

INSERT INTO @trabajos VALUES
(N'Propi - Respaldo completo',     CONCAT(N'EXEC dbo.pa_respaldar ''COMPLETO'', N''', @ruta, N''';'),    8, 1,  1, 0,  3000),
(N'Propi - Respaldo diferencial',  CONCAT(N'EXEC dbo.pa_respaldar ''DIFERENCIAL'', N''', @ruta, N''';'), 8, 126, 1, 0, 3000),
(N'Propi - Respaldo de log',       CONCAT(N'EXEC dbo.pa_respaldar ''LOG'', N''', @ruta, N''';'),         4, 1,  2, 30, 0),
(N'Propi - Respaldo de llaves',    CONCAT(N'EXEC dbo.pa_respaldar ''LLAVES'', N''', @ruta, N''', N''Propi#Llaves2026'';'), 16, 1, 1, 0, 1500),
(N'Propi - Limpieza de respaldos', CONCAT(N'DECLARE @f1 DATETIME = DATEADD(DAY, -35, GETDATE()), @f2 DATETIME = DATEADD(DAY, -8, GETDATE());',
                                          N'EXEC master.sys.xp_delete_file 0, N''', @ruta, N''', N''bak'', @f1, 0;',
                                          N'EXEC master.sys.xp_delete_file 0, N''', @ruta, N''', N''trn'', @f2, 0;'), 4, 1, 1, 0, 20000);

DECLARE @i INT = 1, @nombre SYSNAME, @comando NVARCHAR(MAX), @ft INT, @fi INT, @st INT, @si INT, @hora INT;
DECLARE @id UNIQUEIDENTIFIER;

WHILE @i <= (SELECT COUNT(*) FROM @trabajos)
BEGIN
    SELECT @nombre = nombre, @comando = comando, @ft = freq_type, @fi = freq_interval,
           @st = subday_type, @si = subday_interval, @hora = hora
    FROM @trabajos WHERE n = @i;

    IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @nombre)
        EXEC dbo.sp_delete_job @job_name = @nombre;

    SET @id = NULL;
    EXEC dbo.sp_add_job @job_name = @nombre, @enabled = 1, @owner_login_name = N'sa',
         @description = N'Respaldos de Propi (REQ 013)', @job_id = @id OUTPUT;
    EXEC dbo.sp_add_jobstep @job_id = @id, @step_name = N'Ejecutar', @subsystem = N'TSQL',
         @database_name = @base, @command = @comando, @retry_attempts = 1, @retry_interval = 1;
    EXEC dbo.sp_add_jobschedule @job_id = @id, @name = @nombre, @enabled = 1,
         @freq_type = @ft, @freq_interval = @fi, @freq_recurrence_factor = 1,
         @freq_subday_type = @st, @freq_subday_interval = @si, @active_start_time = @hora;
    EXEC dbo.sp_add_jobserver @job_id = @id, @server_name = N'(local)';

    SET @i += 1;
END;
GO

--Trabajos creados
SELECT j.name AS trabajo, j.enabled AS habilitado, s.name AS horario,
       CASE s.freq_type WHEN 4 THEN 'Diario' WHEN 8 THEN 'Semanal' WHEN 16 THEN 'Mensual' END AS frecuencia,
       CASE s.freq_subday_type WHEN 2 THEN CONCAT('cada ', s.freq_subday_interval, ' segundos') END AS repeticion
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
WHERE j.name LIKE N'Propi - %'
ORDER BY j.name;
GO
