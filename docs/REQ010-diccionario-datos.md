# REQ 010 · Diccionario de datos

Base de datos **PropiFacturacion_AAMM** (SQL Server). El diccionario se genera desde la base: las descripciones están guardadas como propiedades extendidas (`MS_Description` y `NombreLogico`) por `database/15_diccionario.sql`, y se consultan con las vistas `dbo.v_diccionario_tablas`, `dbo.v_diccionario_columnas` y `dbo.v_diccionario_restricciones`. Si cambia una columna, basta volver a ejecutar las vistas.

## Convenciones

| Prefijo | Significado | Prefijo | Significado |
|---|---|---|---|
| `cod_` | Código o llave | `fec_` | Fecha |
| `num_` | Número | `ind_` | Indicador |
| `nom_` | Nombre | `mon_` | Monto |
| `des_` | Descripción o texto | `can_` | Cantidad |
| `por_` | Porcentaje | | |

Restricciones: `PK_` llave primaria, `FK_` llave foránea, `UQ_` única, `CK_` validación, `DF_` valor por defecto.

Esquemas: **facturacion** (negocio, filegroup PRIMARY) y **auditoria** (bitácoras, filegroup FG_AUDITORIA).

## Resumen de tablas

| Esquema | Nombre físico | Nombre lógico | Descripción | Filegroup |
|---|---|---|---|---|
| facturacion | `clientes` | Cliente | Personas físicas o jurídicas a las que Propi les factura. La identificación, el correo y el teléfono se guardan cifrados con AES-256. | PRIMARY |
| facturacion | `condiciones_venta` | Condición de venta | Catálogo de condiciones de venta de una factura (contado o crédito). | PRIMARY |
| facturacion | `estados` | Estado | Catálogo de estados de un registro (activo o inactivo). Lo usan clientes, productos y tipos de impuesto. | PRIMARY |
| facturacion | `facturas` | Factura | Encabezado de la factura electrónica. Los montos los calcula pa_facturas_insertar a partir del detalle. | PRIMARY |
| facturacion | `facturas_detalle` | Línea de factura | Líneas de una factura. Guardan el precio y el impuesto del día de la venta. | PRIMARY |
| facturacion | `medios_pago` | Medio de pago | Catálogo de medios con los que se paga una factura. | PRIMARY |
| facturacion | `monedas` | Moneda | Catálogo de monedas en que se emite una factura, con su código ISO 4217. | PRIMARY |
| facturacion | `notas_credito_debito` | Nota de crédito o débito | Ajustes sobre una factura emitida. Las de crédito no pueden superar el total de la factura. | PRIMARY |
| facturacion | `productos_servicios` | Producto o servicio | Productos y servicios inmobiliarios que se facturan, con su código CABYS, precio e impuesto. | PRIMARY |
| facturacion | `tipos_identificacion` | Tipo de identificación | Catálogo de tipos de identificación de Hacienda para los clientes. | PRIMARY |
| facturacion | `tipos_impuesto` | Tipo de impuesto | Tarifas del impuesto al valor agregado según los códigos de Hacienda. | PRIMARY |
| facturacion | `tipos_nota` | Tipo de nota | Catálogo de tipos de nota sobre una factura (crédito o débito). | PRIMARY |
| facturacion | `unidades_medida` | Unidad de medida | Catálogo de unidades en que se vende un producto o servicio inmobiliario. | PRIMARY |
| auditoria | `bitacora_acceso` | Bitácora de accesos | Registro de cada ingreso y salida de un usuario a la aplicación (REQ 003). | FG_AUDITORIA |
| auditoria | `bitacora_auditoria` | Bitácora de auditoría | Registro de cada inserción, modificación y borrado en las tablas del negocio, escrito por los triggers (REQ 005). | FG_AUDITORIA |
| auditoria | `medicion_rendimiento` | Medición de rendimiento | Resultados de pa_medir_rendimiento: métricas de los procedimientos antes y después de los índices (REQ 009). | FG_AUDITORIA |

## 1. facturacion.clientes

- **Nombre lógico:** Cliente
- **Esquema:** facturacion
- **Descripción:** Personas físicas o jurídicas a las que Propi les factura. La identificación, el correo y el teléfono se guardan cifrados con AES-256.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_cliente` | int | No | IDENTITY(1,1) | PK | Código consecutivo del cliente. |
| `nom_cliente` | varchar(150) | No | — | — | Nombre completo o razón social del cliente. |
| `cod_tipo_identificacion` | int | No | — | UQ, FK → facturacion.tipos_identificacion | Tipo de identificación del cliente. |
| `num_identificacion` | varbinary(256) | No | — | — | Número de identificación cifrado con la llave simétrica llave_clientes (AES-256). Dato confidencial. |
| `cod_hash_identificacion` | varbinary(32) | No | — | UQ | Hash SHA2_256 de la identificación. Permite validar que no se repita, porque el valor cifrado cambia en cada encriptación. |
| `des_provincia` | varchar(50) | No | — | — | Provincia del domicilio del cliente. |
| `des_canton` | varchar(50) | No | — | — | Cantón del domicilio del cliente. |
| `des_distrito` | varchar(50) | No | — | — | Distrito del domicilio del cliente. |
| `des_barrio` | varchar(100) | Sí | — | — | Barrio u otras señas del domicilio (opcional). |
| `des_profesion` | varchar(100) | Sí | — | — | Profesión del cliente (opcional). |
| `des_actividad_economica` | varchar(150) | Sí | — | — | Actividad económica del cliente (opcional). |
| `des_correo` | varbinary(512) | No | — | — | Correo electrónico cifrado con AES-256. Dato confidencial. |
| `num_telefono` | varbinary(256) | No | — | — | Teléfono cifrado con AES-256. Dato confidencial. |
| `fec_registro` | datetime | No | (getdate()) | — | Fecha y hora en que se registró el cliente. |
| `cod_estado` | char(1) | No | ('A') | FK → facturacion.estados | Estado del cliente: A = Activo, I = Inactivo. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `FK_clientes_estados` | FOREIGN KEY | `cod_estado → facturacion.estados` |
| `FK_clientes_tipos_identificacion` | FOREIGN KEY | `cod_tipo_identificacion → facturacion.tipos_identificacion` |
| `PK_clientes` | PRIMARY KEY | `cod_cliente` |
| `UQ_clientes_identificacion` | UNIQUE | `cod_tipo_identificacion, cod_hash_identificacion` |

## 2. facturacion.condiciones_venta

- **Nombre lógico:** Condición de venta
- **Esquema:** facturacion
- **Descripción:** Catálogo de condiciones de venta de una factura (contado o crédito).

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_condicion_venta` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la condición de venta. |
| `des_condicion_venta` | varchar(30) | No | — | UQ | Nombre de la condición de venta. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_condiciones_venta` | PRIMARY KEY | `cod_condicion_venta` |
| `UQ_condiciones_venta_des` | UNIQUE | `des_condicion_venta` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 1 | Contado |
| 2 | Crédito |

## 3. facturacion.estados

- **Nombre lógico:** Estado
- **Esquema:** facturacion
- **Descripción:** Catálogo de estados de un registro (activo o inactivo). Lo usan clientes, productos y tipos de impuesto.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_estado` | char(1) | No | — | PK | Código del estado: A = Activo, I = Inactivo. |
| `des_estado` | varchar(30) | No | — | UQ | Nombre del estado. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_estados` | PRIMARY KEY | `cod_estado` |
| `UQ_estados_des` | UNIQUE | `des_estado` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| A | Activo |
| I | Inactivo |

## 4. facturacion.facturas

- **Nombre lógico:** Factura
- **Esquema:** facturacion
- **Descripción:** Encabezado de la factura electrónica. Los montos los calcula pa_facturas_insertar a partir del detalle.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_factura` | int | No | IDENTITY(1,1) | PK | Número consecutivo de la factura. |
| `cod_cliente` | int | No | — | FK → facturacion.clientes | Cliente al que se le factura. |
| `fec_factura` | datetime | No | (getdate()) | — | Fecha y hora de emisión. |
| `cod_condicion_venta` | int | No | — | FK → facturacion.condiciones_venta | Condición de venta (contado o crédito). |
| `cod_medio_pago` | int | No | — | FK → facturacion.medios_pago | Medio de pago. |
| `cod_moneda` | int | No | — | FK → facturacion.monedas | Moneda de la factura. |
| `mon_tipo_cambio` | decimal(18,4) | No | ((1)) | — | Tipo de cambio respecto al colón. Es 1 cuando la factura es en colones. |
| `des_observaciones` | varchar(500) | Sí | — | — | Observaciones de la factura (opcional). |
| `mon_subtotal` | decimal(18,2) | No | ((0)) | — | Suma de las líneas sin impuesto. La calcula el procedimiento. |
| `mon_total_impuestos` | decimal(18,2) | No | ((0)) | — | Suma del impuesto de las líneas. La calcula el procedimiento. |
| `mon_total` | decimal(18,2) | No | ((0)) | — | Subtotal más impuestos. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_facturas_montos` | CHECK | `([mon_subtotal]>=(0) AND [mon_total_impuestos]>=(0) AND [mon_total]>=(0))` |
| `CK_facturas_tipo_cambio` | CHECK | `([mon_tipo_cambio]>(0))` |
| `FK_facturas_clientes` | FOREIGN KEY | `cod_cliente → facturacion.clientes` |
| `FK_facturas_condiciones_venta` | FOREIGN KEY | `cod_condicion_venta → facturacion.condiciones_venta` |
| `FK_facturas_medios_pago` | FOREIGN KEY | `cod_medio_pago → facturacion.medios_pago` |
| `FK_facturas_monedas` | FOREIGN KEY | `cod_moneda → facturacion.monedas` |
| `PK_facturas` | PRIMARY KEY | `cod_factura` |

## 5. facturacion.facturas_detalle

- **Nombre lógico:** Línea de factura
- **Esquema:** facturacion
- **Descripción:** Líneas de una factura. Guardan el precio y el impuesto del día de la venta.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_detalle` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la línea. |
| `cod_factura` | int | No | — | FK → facturacion.facturas | Factura a la que pertenece la línea. |
| `cod_producto` | int | No | — | FK → facturacion.productos_servicios | Producto o servicio facturado. |
| `can_cantidad` | decimal(18,2) | No | — | — | Cantidad vendida, mayor que cero. |
| `mon_precio_unitario` | decimal(18,2) | No | — | — | Precio unitario del día de la venta. |
| `mon_impuesto` | decimal(18,2) | No | — | — | Monto de impuesto de la línea. |
| `mon_linea` | decimal(18,2) | No | — | — | Cantidad por precio unitario, sin impuesto. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_facturas_detalle_cantidad` | CHECK | `([can_cantidad]>(0))` |
| `CK_facturas_detalle_montos` | CHECK | `([mon_precio_unitario]>=(0) AND [mon_impuesto]>=(0) AND [mon_linea]>=(0))` |
| `FK_facturas_detalle_facturas` | FOREIGN KEY | `cod_factura → facturacion.facturas` |
| `FK_facturas_detalle_productos` | FOREIGN KEY | `cod_producto → facturacion.productos_servicios` |
| `PK_facturas_detalle` | PRIMARY KEY | `cod_detalle` |

## 6. facturacion.medios_pago

- **Nombre lógico:** Medio de pago
- **Esquema:** facturacion
- **Descripción:** Catálogo de medios con los que se paga una factura.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_medio_pago` | int | No | IDENTITY(1,1) | PK | Código consecutivo del medio de pago. |
| `des_medio_pago` | varchar(30) | No | — | UQ | Nombre del medio de pago. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_medios_pago` | PRIMARY KEY | `cod_medio_pago` |
| `UQ_medios_pago_des` | UNIQUE | `des_medio_pago` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 3 | Cheque |
| 1 | Efectivo |
| 6 | Otros |
| 5 | SINPE Móvil |
| 2 | Tarjeta |
| 4 | Transferencia |

## 7. facturacion.monedas

- **Nombre lógico:** Moneda
- **Esquema:** facturacion
- **Descripción:** Catálogo de monedas en que se emite una factura, con su código ISO 4217.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_moneda` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la moneda. |
| `cod_iso` | char(3) | No | — | UQ | Código ISO 4217 de tres letras (CRC, USD). |
| `des_moneda` | varchar(30) | No | — | — | Nombre de la moneda. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_monedas` | PRIMARY KEY | `cod_moneda` |
| `UQ_monedas_iso` | UNIQUE | `cod_iso` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 1 | CRC - Colón costarricense |
| 2 | USD - Dólar estadounidense |

## 8. facturacion.notas_credito_debito

- **Nombre lógico:** Nota de crédito o débito
- **Esquema:** facturacion
- **Descripción:** Ajustes sobre una factura emitida. Las de crédito no pueden superar el total de la factura.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_nota` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la nota. |
| `fec_nota` | datetime | No | (getdate()) | — | Fecha y hora de la nota. |
| `cod_factura` | int | No | — | FK → facturacion.facturas | Factura que se ajusta. |
| `cod_tipo_nota` | int | No | — | FK → facturacion.tipos_nota | Tipo de nota (crédito o débito). |
| `des_motivo` | varchar(300) | No | — | — | Motivo del ajuste. |
| `mon_nota` | decimal(18,2) | No | — | — | Monto de la nota, mayor que cero. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_notas_monto` | CHECK | `([mon_nota]>(0))` |
| `FK_notas_facturas` | FOREIGN KEY | `cod_factura → facturacion.facturas` |
| `FK_notas_tipos_nota` | FOREIGN KEY | `cod_tipo_nota → facturacion.tipos_nota` |
| `PK_notas_credito_debito` | PRIMARY KEY | `cod_nota` |

## 9. facturacion.productos_servicios

- **Nombre lógico:** Producto o servicio
- **Esquema:** facturacion
- **Descripción:** Productos y servicios inmobiliarios que se facturan, con su código CABYS, precio e impuesto.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_producto` | int | No | IDENTITY(1,1) | PK | Código consecutivo del producto o servicio. |
| `cod_cabys` | varchar(13) | No | — | UQ | Código CABYS de 13 dígitos del catálogo de bienes y servicios de Hacienda. |
| `des_producto` | varchar(200) | No | — | — | Descripción del producto o servicio. |
| `cod_unidad_medida` | int | No | — | FK → facturacion.unidades_medida | Unidad en que se vende. |
| `mon_precio` | decimal(18,2) | No | — | — | Precio unitario vigente, sin impuesto. |
| `cod_tipo_impuesto` | int | No | — | FK → facturacion.tipos_impuesto | Tarifa de impuesto que se le aplica. |
| `cod_estado` | char(1) | No | ('A') | FK → facturacion.estados | Estado del producto: A = Activo, I = Inactivo. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_productos_servicios_precio` | CHECK | `([mon_precio]>=(0))` |
| `FK_productos_estados` | FOREIGN KEY | `cod_estado → facturacion.estados` |
| `FK_productos_tipos_impuesto` | FOREIGN KEY | `cod_tipo_impuesto → facturacion.tipos_impuesto` |
| `FK_productos_unidades_medida` | FOREIGN KEY | `cod_unidad_medida → facturacion.unidades_medida` |
| `PK_productos_servicios` | PRIMARY KEY | `cod_producto` |
| `UQ_productos_servicios_cabys` | UNIQUE | `cod_cabys` |

## 10. facturacion.tipos_identificacion

- **Nombre lógico:** Tipo de identificación
- **Esquema:** facturacion
- **Descripción:** Catálogo de tipos de identificación de Hacienda para los clientes.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_tipo_identificacion` | int | No | IDENTITY(1,1) | PK | Código consecutivo del tipo de identificación. |
| `des_tipo_identificacion` | varchar(50) | No | — | UQ | Nombre del tipo de identificación (cédula física, jurídica, DIMEX, NITE, pasaporte). |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_tipos_identificacion` | PRIMARY KEY | `cod_tipo_identificacion` |
| `UQ_tipos_identificacion_des` | UNIQUE | `des_tipo_identificacion` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 1 | Cédula física |
| 2 | Cédula jurídica |
| 3 | DIMEX |
| 4 | NITE |
| 5 | Pasaporte |

## 11. facturacion.tipos_impuesto

- **Nombre lógico:** Tipo de impuesto
- **Esquema:** facturacion
- **Descripción:** Tarifas del impuesto al valor agregado según los códigos de Hacienda.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_tipo_impuesto` | int | No | IDENTITY(1,1) | PK | Código consecutivo del tipo de impuesto. |
| `cod_tarifa` | varchar(2) | No | — | UQ | Código de tarifa de Hacienda (01, 02, 04, 08). |
| `des_tipo_impuesto` | varchar(100) | No | — | — | Nombre de la tarifa. |
| `por_impuesto` | decimal(5,2) | No | — | — | Porcentaje de impuesto, de 0 a 100. |
| `cod_estado` | char(1) | No | ('A') | FK → facturacion.estados | Estado de la tarifa: A = Activo, I = Inactivo. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_tipos_impuesto_porcentaje` | CHECK | `([por_impuesto]>=(0) AND [por_impuesto]<=(100))` |
| `FK_tipos_impuesto_estados` | FOREIGN KEY | `cod_estado → facturacion.estados` |
| `PK_tipos_impuesto` | PRIMARY KEY | `cod_tipo_impuesto` |
| `UQ_tipos_impuesto_tarifa` | UNIQUE | `cod_tarifa` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 01 | Tarifa 0% (exento) (0.00 %) |
| 02 | Tarifa reducida 1% (1.00 %) |
| 04 | Tarifa reducida 4% (4.00 %) |
| 08 | Tarifa general 13% (13.00 %) |

## 12. facturacion.tipos_nota

- **Nombre lógico:** Tipo de nota
- **Esquema:** facturacion
- **Descripción:** Catálogo de tipos de nota sobre una factura (crédito o débito).

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_tipo_nota` | int | No | IDENTITY(1,1) | PK | Código consecutivo del tipo de nota: 1 = Crédito, 2 = Débito. |
| `des_tipo_nota` | varchar(30) | No | — | UQ | Nombre del tipo de nota. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_tipos_nota` | PRIMARY KEY | `cod_tipo_nota` |
| `UQ_tipos_nota_des` | UNIQUE | `des_tipo_nota` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 1 | Crédito |
| 2 | Débito |

## 13. facturacion.unidades_medida

- **Nombre lógico:** Unidad de medida
- **Esquema:** facturacion
- **Descripción:** Catálogo de unidades en que se vende un producto o servicio inmobiliario.

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_unidad_medida` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la unidad de medida. |
| `des_unidad_medida` | varchar(50) | No | — | UQ | Nombre de la unidad de medida. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_unidades_medida` | PRIMARY KEY | `cod_unidad_medida` |
| `UQ_unidades_medida_des` | UNIQUE | `des_unidad_medida` |

**Valores del catálogo**

| Código | Significado |
|---|---|
| 4 | Hectárea |
| 3 | Metro cuadrado |
| 2 | Servicio |
| 1 | Unidad |

## 14. auditoria.bitacora_acceso

- **Nombre lógico:** Bitácora de accesos
- **Esquema:** auditoria
- **Descripción:** Registro de cada ingreso y salida de un usuario a la aplicación (REQ 003).

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_acceso` | int | No | IDENTITY(1,1) | PK | Código de la sesión. Se guarda en el JWT y lo usan los triggers como cod_sesion_usuario. |
| `nom_usuario` | varchar(128) | No | — | — | Login de SQL Server del usuario. |
| `nom_terminal` | varchar(128) | Sí | — | — | Nombre del equipo desde donde ingresó. |
| `des_direccion_ip` | varchar(48) | Sí | — | — | Dirección IP del cliente. |
| `fec_ingreso` | datetime | No | — | — | Fecha y hora de ingreso. |
| `fec_salida` | datetime | Sí | — | — | Fecha y hora de salida. Nula mientras la sesión está abierta. |
| `fec_registro` | datetime | No | (getdate()) | — | Fecha y hora en que se escribió el registro. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `PK_bitacora_acceso` | PRIMARY KEY | `cod_acceso` |

## 15. auditoria.bitacora_auditoria

- **Nombre lógico:** Bitácora de auditoría
- **Esquema:** auditoria
- **Descripción:** Registro de cada inserción, modificación y borrado en las tablas del negocio, escrito por los triggers (REQ 005).

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `fec_registro` | datetime | No | (getdate()) | — | Fecha y hora del cambio. |
| `cod_guid` | varchar(255) | Sí | (CONVERT([varchar](255),newid())) | — | Identificador único del registro de auditoría. |
| `ind_accion` | char(1) | No | — | — | Acción: I = Inserción, U = Modificación, D = Borrado. |
| `cod_usuario` | char(128) | No | — | — | Usuario de base de datos que hizo el cambio. |
| `cod_sesion_usuario` | int | Sí | — | — | Sesión de la bitácora de accesos en que se hizo el cambio. |
| `cod_tabla` | varchar(255) | No | — | — | Tabla modificada (esquema.tabla). |
| `cod_llave` | varchar(2000) | Sí | — | — | Llave primaria del registro modificado. |
| `des_datos` | varchar(MAX) | Sí | — | — | Datos del registro en JSON: los nuevos en inserción y modificación, los anteriores en borrado. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_bitacora_auditoria_accion` | CHECK | `([ind_accion]='U' OR [ind_accion]='D' OR [ind_accion]='I')` |

## 16. auditoria.medicion_rendimiento

- **Nombre lógico:** Medición de rendimiento
- **Esquema:** auditoria
- **Descripción:** Resultados de pa_medir_rendimiento: métricas de los procedimientos antes y después de los índices (REQ 009).

| Columna | Tipo de dato | Nulos | Valor por defecto | Llaves | Descripción |
|---|---|---|---|---|---|
| `cod_medicion` | int | No | IDENTITY(1,1) | PK | Código consecutivo de la medición. |
| `des_fase` | varchar(10) | No | — | — | Fase: ANTES o DESPUES de crear los índices. |
| `des_prueba` | varchar(100) | No | — | — | Nombre de la prueba. |
| `nom_procedimiento` | varchar(128) | No | — | — | Procedimiento medido. |
| `can_ejecuciones` | int | No | — | — | Cantidad de ejecuciones promediadas. |
| `num_ms_promedio` | decimal(12,3) | No | — | — | Tiempo promedio en milisegundos. |
| `num_cpu_ms_promedio` | decimal(12,3) | No | — | — | Tiempo de CPU promedio en milisegundos. |
| `num_lecturas_promedio` | decimal(14,1) | No | — | — | Lecturas lógicas promedio (páginas de 8 KB). |
| `des_plan` | varchar(MAX) | Sí | — | — | Operadores del plan de ejecución. |
| `fec_medicion` | datetime | No | (getdate()) | — | Fecha y hora de la medición. |

**Restricciones**

| Nombre | Tipo | Detalle |
|---|---|---|
| `CK_medicion_fase` | CHECK | `([des_fase]='DESPUES' OR [des_fase]='ANTES')` |
| `PK_medicion_rendimiento` | PRIMARY KEY | `cod_medicion` |

## Otros valores codificados

| Tabla.columna | Valores |
|---|---|
| `bitacora_auditoria.ind_accion` | I = Inserción, U = Modificación, D = Borrado |
| `medicion_rendimiento.des_fase` | ANTES, DESPUES |

## Columnas cifradas

`clientes.num_identificacion`, `clientes.des_correo` y `clientes.num_telefono` se guardan como `VARBINARY` cifrado con la llave simétrica `llave_clientes` (AES-256), protegida por el certificado `cert_clientes` y la master key de la base (`03_cifrado.sql`). Solo los procedimientos almacenados las descifran con `DECRYPTBYKEY`. Como el valor cifrado cambia en cada encriptación, la unicidad de la identificación se controla con `cod_hash_identificacion` (SHA2_256).
