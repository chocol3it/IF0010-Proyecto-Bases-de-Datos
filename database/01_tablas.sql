/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   01 - Tablas, llaves y restricciones
   -------------------------------------------------------------
   Nomenclatura de columnas (igual que la bitácora del enunciado):
     cod_ código / llave      num_ número       nom_ nombre
     des_ descripción / texto fec_ fecha        ind_ indicador
     mon_ monto               can_ cantidad     por_ porcentaje
   OJO: este script borra y vuelve a crear las tablas (se pierden
   los datos). Úselo solo para montar la base desde cero.
   ============================================================= */
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

-- num_identificacion, num_telefono y des_correo se cifrarán (REQ 006)
-- después del primer punto de control; se pasarán a VARBINARY.
CREATE TABLE facturacion.clientes (
    cod_cliente             INT IDENTITY(1,1) NOT NULL,
    nom_cliente             VARCHAR(150)      NOT NULL,
    cod_tipo_identificacion INT               NOT NULL,
    num_identificacion      VARCHAR(20)       NOT NULL,
    des_provincia           VARCHAR(50)       NOT NULL,
    des_canton              VARCHAR(50)       NOT NULL,
    des_distrito            VARCHAR(50)       NOT NULL,
    des_barrio              VARCHAR(100)      NULL,
    des_profesion           VARCHAR(100)      NULL,
    des_actividad_economica VARCHAR(150)      NULL,
    des_correo              VARCHAR(150)      NOT NULL,
    num_telefono            VARCHAR(20)       NOT NULL,
    fec_registro            DATETIME          NOT NULL CONSTRAINT DF_clientes_fec_registro DEFAULT GETDATE(),
    cod_estado              CHAR(1)           NOT NULL CONSTRAINT DF_clientes_estado DEFAULT 'A',
    CONSTRAINT PK_clientes PRIMARY KEY (cod_cliente),
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
