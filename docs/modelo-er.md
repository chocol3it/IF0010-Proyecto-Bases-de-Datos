# Modelo entidad-relación y grafo relacional (REQ 001)

Base de datos `PropiFacturacion_AAMM`.

## Modelo entidad-relación

Notación de Chen: rectángulo = entidad, rombo = relación (1 / N), óvalo = atributo,
subrayado = llave primaria, punteado = atributo derivado.

![Modelo entidad-relación](modelo-er-chen.png)

## Grafo relacional

```mermaid
erDiagram
    estados ||--o{ clientes : "estado de"
    estados ||--o{ tipos_impuesto : "estado de"
    estados ||--o{ productos_servicios : "estado de"
    tipos_identificacion ||--o{ clientes : "identifica"
    clientes ||--o{ facturas : "recibe"
    condiciones_venta ||--o{ facturas : "condición de"
    medios_pago ||--o{ facturas : "se paga con"
    monedas ||--o{ facturas : "expresada en"
    facturas ||--|{ facturas_detalle : "contiene"
    productos_servicios ||--o{ facturas_detalle : "se vende en"
    unidades_medida ||--o{ productos_servicios : "se mide en"
    tipos_impuesto ||--o{ productos_servicios : "grava"
    facturas ||--o{ notas_credito_debito : "se ajusta con"
    tipos_nota ||--o{ notas_credito_debito : "tipo de"

    clientes {
        INT cod_cliente PK
        VARCHAR nom_cliente
        INT cod_tipo_identificacion FK
        VARCHAR num_identificacion "sensible"
        VARCHAR des_provincia
        VARCHAR des_canton
        VARCHAR des_distrito
        VARCHAR des_barrio
        VARCHAR des_profesion
        VARCHAR des_actividad_economica
        VARCHAR des_correo "sensible"
        VARCHAR num_telefono "sensible"
        DATETIME fec_registro
        CHAR cod_estado FK
    }
    tipos_impuesto {
        INT cod_tipo_impuesto PK
        VARCHAR cod_tarifa UK
        VARCHAR des_tipo_impuesto
        DECIMAL por_impuesto
        CHAR cod_estado FK
    }
    productos_servicios {
        INT cod_producto PK
        VARCHAR cod_cabys UK
        VARCHAR des_producto
        INT cod_unidad_medida FK
        DECIMAL mon_precio
        INT cod_tipo_impuesto FK
        CHAR cod_estado FK
    }
    facturas {
        INT cod_factura PK
        INT cod_cliente FK
        DATETIME fec_factura
        INT cod_condicion_venta FK
        INT cod_medio_pago FK
        INT cod_moneda FK
        DECIMAL mon_tipo_cambio
        VARCHAR des_observaciones
        DECIMAL mon_subtotal
        DECIMAL mon_total_impuestos
        DECIMAL mon_total
    }
    facturas_detalle {
        INT cod_detalle PK
        INT cod_factura FK
        INT cod_producto FK
        DECIMAL can_cantidad
        DECIMAL mon_precio_unitario
        DECIMAL mon_impuesto
        DECIMAL mon_linea
    }
    notas_credito_debito {
        INT cod_nota PK
        DATETIME fec_nota
        INT cod_factura FK
        INT cod_tipo_nota FK
        VARCHAR des_motivo
        DECIMAL mon_nota
    }
    estados {
        CHAR cod_estado PK
        VARCHAR des_estado
    }
    tipos_identificacion {
        INT cod_tipo_identificacion PK
        VARCHAR des_tipo_identificacion
    }
    condiciones_venta {
        INT cod_condicion_venta PK
        VARCHAR des_condicion_venta
    }
    medios_pago {
        INT cod_medio_pago PK
        VARCHAR des_medio_pago
    }
    monedas {
        INT cod_moneda PK
        CHAR cod_iso UK
        VARCHAR des_moneda
    }
    unidades_medida {
        INT cod_unidad_medida PK
        VARCHAR des_unidad_medida
    }
    tipos_nota {
        INT cod_tipo_nota PK
        VARCHAR des_tipo_nota
    }
    bitacora_acceso {
        INT cod_acceso PK
        VARCHAR nom_usuario
        VARCHAR nom_terminal
        VARCHAR des_direccion_ip
        DATETIME fec_ingreso
        DATETIME fec_salida
        DATETIME fec_registro
    }
    bitacora_auditoria {
        DATETIME fec_registro
        VARCHAR cod_guid
        CHAR ind_accion
        CHAR cod_usuario
        INT cod_sesion_usuario
        VARCHAR cod_tabla
        VARCHAR cod_llave
        VARCHAR des_datos
    }
```
