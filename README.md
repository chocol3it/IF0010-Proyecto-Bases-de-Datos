# Propi - Sistema de Facturación

**Curso:** IF0010 - Bases de Datos II
**Ciclo:** II-2026
**Proyecto:** Sistema de gestión de facturación para la Proptech Propi

## Estructura

| Carpeta | Contenido |
|---|---|
| `database/` | Scripts de SQL Server, numerados en el orden de ejecución |
| `docs/` | Modelo entidad-relación y grafo relacional |
| `propi-backend/` | API REST en Spring Boot 4 (Java 21, Spring JDBC, Spring Security con JWT) |
| `propi-frontend/` | SPA en Angular 22 |

## 1. Preparar SQL Server local (una sola vez)

El proyecto usa logins de SQL Server, por lo que el servidor debe aceptar **autenticación mixta**
y Spring Boot se conecta por **TCP en el puerto 1433**.

1. SSMS → clic derecho sobre el servidor → *Propiedades* → *Seguridad* →
   **Modo de autenticación de SQL Server y Windows** → Aceptar.
2. *SQL Server Configuration Manager* → *Configuración de red de SQL Server* →
   *Protocolos de SQLEXPRESS* → **TCP/IP: Habilitado**. En *Propiedades de TCP/IP* → pestaña
   *Direcciones IP* → sección *IPAll*: **Puertos TCP dinámicos** vacío y **Puerto TCP = 1433**.
3. Reiniciar el servicio *SQL Server (SQLEXPRESS)*.

## 2. Base de datos

Base de datos: `PropiFacturacion_AAMM`. Ejecutar en SSMS, en orden:

| Script | Contenido | REQ |
|---|---|---|
| `00_crear_bd.sql` | BD, filegroup `FG_AUDITORIA`, aislamiento snapshot, esquemas `facturacion` y `auditoria` | 001 |
| `01_tablas.sql` | Catálogos, entidades y bitácoras con PK, FK, UNIQUE y CHECK. **Borra y recrea las tablas.** | 001 |
| `02_catalogos.sql` | Datos de los catálogos | 001 |
| `03_cifrado.sql` | Master key, certificado y llave simétrica AES_256 | 006 |
| `04_procedimientos_clientes.sql` | CRUD de clientes con cifrado de datos sensibles | 002, 006 |
| `05_procedimientos_impuestos_productos.sql` | CRUD de tipos de impuesto y productos | 002 |
| `06_procedimientos_facturas_notas.sql` | Factura con detalle en una sola transacción, notas de crédito/débito | 002 |
| `07_procedimientos_catalogos.sql` | Listas de catálogos para los formularios | 002 |
| `08_procedimientos_acceso.sql` | Bitácora de accesos (ingreso y salida) | 003 |
| `09_triggers.sql` | 3 triggers de auditoría por tabla | 005 |
| `10_reportes.sql` | 4 reportes con aislamiento snapshot | 007 |
| `11_seguridad.sql` | Logins, usuarios, roles y permisos GRANT / REVOKE / DENY | 003, 004, 008 |

### Usuarios de prueba

| Usuario | Contraseña | Rol | Acceso |
|---|---|---|---|
| `propi_admin` | `Admin#2026` | `rol_administrador` | Todo |
| `propi_digitador` | `Digitador#2026` | `rol_digitador` | Clientes, facturas y notas |
| `propi_consulta` | `Consulta#2026` | `rol_consulta` | Reportes |
| `propi_app` | `PropiApp#2026` | — | Login técnico del backend: solo puede suplantar a los usuarios anteriores |

### Decisiones de diseño

- **Nomenclatura** igual a la bitácora del enunciado: `cod_` código, `num_` número, `nom_` nombre,
  `des_` descripción, `fec_` fecha, `ind_` indicador, `mon_` monto, `can_` cantidad, `por_` porcentaje.
- **Dos esquemas:** `facturacion` (negocio) y `auditoria` (bitácoras, en su propio filegroup).
- **Catálogos como tablas:** estados, tipos de identificación, condiciones de venta, medios de pago,
  monedas, unidades de medida y tipos de nota.
- **Tipos de impuesto** guardan el código de tarifa de Hacienda (`cod_tarifa`, ej. `08`) y el porcentaje (`por_impuesto`, ej. `13`).
- **Totales de la factura** los calcula el procedimiento almacenado a partir del detalle. El detalle guarda
  el precio unitario y el impuesto del día de la venta. Una factura emitida solo permite modificar datos
  que no afectan montos; los montos se corrigen con notas.
- **Notas de crédito/débito** llevan monto; las de crédito no pueden superar el total de la factura.
- **Cifrado:** identificación, correo y teléfono se guardan como `VARBINARY` cifrado. La unicidad de la
  identificación se controla con su hash SHA2_256.
- **Toda escritura pasa por procedimientos almacenados** con `TRY/CATCH` y `BEGIN/COMMIT/ROLLBACK TRANSACTION`.
  Errores de negocio: `50001` duplicado, `50002` inexistente, `50003` regla de negocio, `50004` usuario sin rol.

## 3. Backend

1. Copiar `propi-backend/application.properties.template` a
   `propi-backend/src/main/resources/application.properties` y cambiar `app.jwt.secret`
   (ese archivo no se sube al repositorio).
2. Ejecutar `./mvnw spring-boot:run` dentro de `propi-backend` (puerto 8080).

**Cómo se aplica la seguridad de SQL Server:**

- **Login:** el backend abre una conexión a SQL Server con el usuario y la contraseña digitados. Si SQL
  Server la acepta, con esa conexión ejecuta `auditoria.pa_acceso_ingresar` (registra el ingreso y devuelve
  el rol) y genera un JWT con el usuario, el rol y el código de sesión.
- **Cada petición:** sobre la conexión técnica `propi_app` se ejecuta
  `EXECUTE AS USER = '<usuario>'` → procedimiento → `REVERT` (ver `data/ConexionBD.java`). Así SQL Server
  aplica los permisos del rol real y los triggers registran al usuario real y su sesión.
- Si el rol no tiene permiso, SQL Server responde con el error 229 y la API devuelve 403.

| Recurso | Rutas |
|---|---|
| Autenticación | `POST /api/v1/auth/login`, `POST /api/v1/auth/logout` |
| Clientes | `GET/POST /api/v1/clientes`, `GET/PUT/DELETE /api/v1/clientes/{id}` |
| Tipos de impuesto | `GET/POST /api/v1/tipos-impuesto`, `GET/PUT/DELETE /api/v1/tipos-impuesto/{id}` |
| Productos | `GET/POST /api/v1/productos`, `GET/PUT/DELETE /api/v1/productos/{id}` |
| Facturas | `GET/POST /api/v1/facturas`, `GET/PUT/DELETE /api/v1/facturas/{id}`, `GET /api/v1/facturas/{id}/detalle` |
| Notas | `GET/POST /api/v1/notas` (`?factura=`), `GET/PUT/DELETE /api/v1/notas/{id}` |
| Catálogos | `GET /api/v1/catalogos/{estados, tipos-identificacion, condiciones-venta, medios-pago, monedas, unidades-medida, tipos-nota}` |
| Reportes | `GET /api/v1/reportes/clientes?desde&hasta&estado`, `/facturas?desde&hasta`, `/auditoria?desde&hasta&usuario`, `/seguridad?usuario` |

## 4. Frontend

```bash
cd propi-frontend
npm install
npm start
```

Abrir `http://localhost:4200` e iniciar sesión con uno de los usuarios de prueba.

## Avance

**Punto de control 1**

- [x] REQ 001 Modelo entidad-relación y grafo relacional (`docs/modelo-er.md`)
- [x] Creación de la BD con filegroup para bitácoras, esquemas y todas las tablas
- [x] CRUD de clientes y triggers de auditoría de clientes

**Punto de control 2**

- [x] REQ 002 CRUD de clientes, tipos de impuesto, productos, facturas con detalle y notas
- [x] REQ 003 Login con usuarios de SQL Server y bitácora de accesos
- [x] REQ 004 / 008 Roles (administrador, digitador, consulta) y permisos con GRANT, REVOKE y DENY
- [x] REQ 005 Triggers de auditoría en todas las tablas
- [x] REQ 006 Cifrado de identificación, teléfono y correo
- [x] REQ 007 Reportes con TRY/CATCH, transacción y aislamiento snapshot
- [ ] REQ 009 Datos de prueba, planes de ejecución e índices
- [ ] REQ 010 a 013 Documentación
- [ ] REQ 014 Réplica
