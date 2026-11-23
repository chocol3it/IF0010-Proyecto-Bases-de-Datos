# Propi - Sistema de Facturación

**Curso:** IF0010 - Bases de Datos II
**Ciclo:** II-2026
**Proyecto:** Sistema de gestión de facturación para la Proptech Propi

## Estructura

| Carpeta | Contenido |
|---|---|
| `database/` | Script único de despliegue (`propi_despliegue.sql`) y anexos de prueba y réplica |
| `docs/` | Modelo entidad-relación, grafo relacional y documentos de los REQ 009 a 014 |
| `propi-backend/` | API REST en Spring Boot 4 (Java 21, Spring JDBC, Spring Security con JWT) |
| `propi-frontend/` | SPA en Angular 22 |

## 1. Preparar SQL Server (una sola vez)

Se usan dos instancias de **SQL Server 2025 Developer** (Express no sirve: no tiene Agente SQL,
necesario para los respaldos programados y la réplica):

| Instancia | Papel | Puerto TCP |
|---|---|---|
| `SQLUCR` | Principal: base de la aplicación | 1433 |
| `SQLSERVERSJ` | Secundaria: réplica con log shipping (REQ 014) | 1435 |

En cada instancia:

1. SSMS → clic derecho sobre el servidor → *Propiedades* → *Seguridad* →
   **Modo de autenticación de SQL Server y Windows**.
2. *SQL Server 2025 Configuration Manager* (`SQLServerManager17.msc`) → *Protocolos de la instancia* →
   **TCP/IP: Habilitado** → *Direcciones IP* → *IPAll*: **Puertos TCP dinámicos** vacío y el **Puerto TCP** de la tabla.
3. *Servicios de SQL Server* → **SQL Server Agent** con inicio *Automático* e iniciado.
4. Reiniciar el servicio de SQL Server de la instancia.

Carpeta de respaldos compartida por las dos instancias (PowerShell como administrador):

```powershell
mkdir C:\PropiRespaldos
icacls C:\PropiRespaldos /grant "NT Service\MSSQL`$SQLUCR:(OI)(CI)M" "NT Service\SQLAgent`$SQLUCR:(OI)(CI)M" "NT Service\MSSQL`$SQLSERVERSJ:(OI)(CI)M" "NT Service\SQLAgent`$SQLSERVERSJ:(OI)(CI)M"
```

## 2. Base de datos

Base de datos: `PropiFacturacion_AAMM`. Toda la base está en un solo script,
`database/propi_despliegue.sql`: abrirlo en SSMS conectado como sysadmin y ejecutarlo completo (F5).

| Sección | Contenido | REQ |
|---|---|---|
| 1 | BD, filegroup `FG_AUDITORIA`, aislamiento snapshot, esquemas `facturacion` y `auditoria` | 001 |
| 2 | Catálogos, entidades y bitácoras con PK, FK, UNIQUE y CHECK. **Borra y recrea las tablas.** | 001 |
| 3 | Datos de los catálogos | 001 |
| 4 | Master key, certificado y llave simétrica AES_256 | 006 |
| 5 a 8 | Procedimientos CRUD (clientes, impuestos, productos, facturas, notas y catálogos) | 002, 006 |
| 9 | Bitácora de accesos (ingreso y salida) | 003 |
| 10 | 3 triggers de auditoría por tabla | 005 |
| 11 | 4 reportes con aislamiento snapshot | 007 |
| 12 | Índice clustered de la bitácora y 7 nonclustered | 009 |
| 13 | Diccionario: propiedades extendidas y vistas `dbo.v_diccionario_*` | 010 |
| 14 | Logins, usuarios, roles y permisos GRANT / REVOKE / DENY | 003, 004, 008 |
| 15 | Modelo FULL y `dbo.pa_respaldar` (completo, diferencial, log y llaves) | 013 |
| 16 | Trabajos del Agente SQL para los respaldos | 013, 014 |

Las secciones 15 y 16 necesitan la carpeta `C:\PropiRespaldos\` con permiso de escritura para el servicio
de SQL Server, y la 16 necesita el Agente SQL (SQL Server Developer o Standard).

Scripts aparte, en `database/anexos/`:

| Anexo | Contenido | REQ |
|---|---|---|
| `01_datos_prueba.sql` | 1 000 clientes, productos y notas, 3 000 facturas, 20 000 registros de auditoría | 009 |
| `02_medicion_rendimiento.sql` | `auditoria.pa_medir_rendimiento` y vista de comparación antes/después | 009 |
| `03_restauracion_prueba.sql` | Restaura la cadena de respaldos en otra base y la verifica | 013 |
| `04_logins_secundaria.sql` | Genera los logins con el mismo SID para la secundaria (se ejecuta en la principal) | 014 |
| `05_replica_secundaria.sql` | Log shipping: copia en STANDBY, aplicación de logs y conmutación (se ejecuta en la secundaria) | 014 |
| `06_prueba_replica.ps1` | Prueba automatizada de RPO y RTO | 014 |

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
**Punto de control 3**

- [x] REQ 009 Datos de prueba, planes de ejecución e índices (`docs/REQ009-planes-indices.md`)
- [x] REQ 010 Diccionario de datos (`docs/REQ010-diccionario-datos.md`)
- [x] REQ 011 Plan de continuidad del negocio (`docs/REQ011-plan-continuidad-negocio.md`)
- [x] REQ 012 Política de seguridad (`docs/REQ012-politica-seguridad.md`)
- [x] REQ 013 Política de respaldos y DRP (`docs/REQ013-politica-respaldos-drp.md`)
- [x] REQ 014 Base secundaria con log shipping (`docs/REQ014-replica.md`)
