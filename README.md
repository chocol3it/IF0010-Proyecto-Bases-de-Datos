# Propi - Sistema de Facturación

**Curso:** IF0010 - Bases de Datos II
**Ciclo:** II-2026
**Proyecto:** Sistema de gestión de facturación para la Proptech Propi

## Estructura

| Carpeta | Contenido |
|---|---|
| `database/` | Scripts de SQL Server, numerados en el orden de ejecución |
| `docs/` | Modelo entidad-relación y grafo relacional |
| `propi-backend/` | API REST en Spring Boot 4 (Java 21, Spring Data JPA) |
| `propi-frontend/` | SPA en Angular 22 |

## Base de datos

Base de datos: `PropiFacturacion_AAMM`. Ejecutar en SSMS, en orden:

1. `00_crear_bd.sql` — crea la BD (si no existe), el filegroup `FG_AUDITORIA` y los esquemas `facturacion` y `auditoria`.
2. `01_tablas.sql` — catálogos, entidades y bitácoras con sus PK, FK y CHECK. **Borra y recrea las tablas.**
3. `02_catalogos.sql` — datos de los catálogos.
4. `03_procedimientos_clientes.sql` — CRUD de clientes por procedimientos almacenados.
5. `04_triggers_clientes.sql` — triggers de auditoría (insert, update, delete) de clientes.

### Decisiones de diseño

- **Nomenclatura** igual a la bitácora del enunciado: `cod_` código, `num_` número, `nom_` nombre,
  `des_` descripción, `fec_` fecha, `ind_` indicador, `mon_` monto, `can_` cantidad, `por_` porcentaje.
- **Dos esquemas:** `facturacion` (negocio) y `auditoria` (bitácoras, en su propio filegroup).
- **Catálogos como tablas:** estados, tipos de identificación, condiciones de venta, medios de pago,
  monedas, unidades de medida y tipos de nota.
- **Tipos de impuesto** guardan el código de tarifa de Hacienda (`cod_tarifa`, ej. `08`) y el porcentaje (`por_impuesto`, ej. `13`).
- **Totales de la factura** los calcula el procedimiento almacenado a partir del detalle. El detalle guarda
  el precio unitario y el impuesto del día de la venta.
- **Notas de crédito/débito** llevan monto y no modifican la factura original.
- **Toda escritura pasa por procedimientos almacenados** con `TRY/CATCH` y `BEGIN/COMMIT/ROLLBACK TRANSACTION`.
  Errores de negocio: `50001` registro duplicado, `50002` registro inexistente, `50003` regla de negocio.

## Backend

1. Copiar `propi-backend/application.properties.template` a
   `propi-backend/src/main/resources/application.properties` y poner la contraseña
   (ese archivo no se sube al repositorio).
2. Ejecutar `./mvnw spring-boot:run` dentro de `propi-backend` (puerto 8080).

| Método | Ruta | Procedimiento |
|---|---|---|
| GET | `/api/v1/clientes` | `pa_clientes_consultar` |
| GET | `/api/v1/clientes/{id}` | `pa_clientes_consultar` |
| POST | `/api/v1/clientes` | `pa_clientes_insertar` |
| PUT | `/api/v1/clientes/{id}` | `pa_clientes_actualizar` |
| DELETE | `/api/v1/clientes/{id}` | `pa_clientes_eliminar` |
| GET | `/api/v1/catalogos/estados` | `pa_estados_listar` |
| GET | `/api/v1/catalogos/tipos-identificacion` | `pa_tipos_identificacion_listar` |

## Frontend

```bash
cd propi-frontend
npm install
npm start
```

Abrir `http://localhost:4200`.

## Avance

**Punto de control 1**

- [x] REQ 001 Modelo entidad-relación y grafo relacional (`docs/modelo-er.md`)
- [x] Creación de la BD con filegroup para bitácoras, esquemas y todas las tablas
- [x] CRUD de clientes por procedimientos almacenados con manejo de transacciones
- [x] Triggers de auditoría de clientes y bitácora en JSON
- [x] Módulo de clientes en la aplicación (Spring Boot + Angular)

**Pendiente**

- [ ] REQ 003 Login con usuarios de SQL Server y bitácora de accesos
- [ ] REQ 004 / 008 Roles (administrador, digitador, consulta) y permisos con GRANT, REVOKE y DENY
- [ ] REQ 005 Triggers de las demás tablas
- [ ] REQ 006 Cifrado de identificación, teléfono y correo
- [ ] REQ 002 CRUD de impuestos, productos, facturas y notas
- [ ] REQ 007 Reportes
- [ ] REQ 009 a 014
