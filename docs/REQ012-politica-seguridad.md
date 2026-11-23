# REQ 012 · Política de seguridad de la información

## 1. Objetivo y alcance

Esta política establece cómo Propi protege la confidencialidad, integridad y disponibilidad de la información del sistema de facturación: la base de datos `PropiFacturacion_AAMM`, el backend, el frontend, los respaldos y las personas que los usan o administran.

Aplica a todo el personal, contratistas y proveedores con acceso al sistema. Su cumplimiento es obligatorio; las excepciones las aprueba por escrito el Líder de TI y se revisan cada 6 meses.

**Marco de referencia:**

- ISO/IEC 27001:2022 (sistema de gestión de seguridad de la información) y los controles de ISO/IEC 27002:2022.
- Ley 8968 de Protección de la Persona frente al Tratamiento de sus Datos Personales (Costa Rica) y su reglamento: Propi guarda identificación, correo y teléfono de personas físicas, por lo que debe garantizar su confidencialidad, usarlos solo para facturar y permitir los derechos de acceso y rectificación de los titulares.

**Responsables:**

| Rol | Responsabilidad |
|---|---|
| Gerente general | Aprueba la política y asigna recursos |
| Líder de TI | Mantiene la política, aprueba excepciones y altas de usuarios administradores |
| Oficial de seguridad | Revisa bitácoras, atiende incidentes y verifica el cumplimiento |
| Administrador de base de datos (DBA) | Aplica los controles técnicos en SQL Server y custodia las llaves |
| Dueños de la información | Clasifican sus datos y autorizan accesos (ver sección 2) |

## 2. Clasificación de la información

### 2.1 Niveles

| Nivel | Definición | Ejemplos | Controles mínimos |
|---|---|---|---|
| **Confidencial** | Su divulgación causa daño legal o a las personas; incluye datos personales protegidos por la Ley 8968 y secretos de seguridad | Identificación, correo y teléfono de clientes; contraseñas; master key, certificado y sus respaldos | Cifrado en reposo y en tránsito, acceso solo por procedimiento y por rol, registro de cada acceso, respaldo cifrado con contraseña |
| **Interna** | Uso de la empresa; su divulgación causa daño comercial | Facturas, montos, notas, nombres y dirección de clientes, bitácoras de auditoría y de accesos, reportes | Acceso por rol, sin acceso directo a tablas, cifrado en tránsito |
| **Pública** | Se puede divulgar sin daño | Catálogos: estados, tipos de identificación, monedas, medios de pago, condiciones de venta, unidades de medida, tarifas de impuesto | Control de integridad (solo el administrador las modifica) |

### 2.2 Inventario por nivel y responsable

| Información | Ubicación | Nivel | Dueño | Custodio |
|---|---|---|---|---|
| `clientes.num_identificacion`, `des_correo`, `num_telefono` | Base, esquema `facturacion` (cifrado AES-256) | Confidencial | Gerente financiero | DBA |
| `clientes.cod_hash_identificacion` | Base | Confidencial | Gerente financiero | DBA |
| Resto de datos de clientes (nombre, dirección, profesión, actividad) | Base | Interna | Gerente financiero | DBA |
| Facturas, detalle y notas de crédito/débito | Base | Interna | Gerente financiero | DBA |
| Productos, servicios y tipos de impuesto | Base | Interna | Gerente comercial | DBA |
| Catálogos | Base | Pública | Líder de TI | DBA |
| Bitácora de accesos y bitácora de auditoría | Base, esquema `auditoria`, filegroup `FG_AUDITORIA` | Interna | Oficial de seguridad | DBA |
| Master key, certificado `cert_clientes`, llave `llave_clientes` y sus archivos de respaldo | Base y carpeta de respaldos | Confidencial | Líder de TI | DBA |
| Contraseñas de logins y secreto JWT (`app.jwt.secret`) | SQL Server, `application.properties` (fuera del repositorio) | Confidencial | Líder de TI | DBA y desarrollador backend |
| Respaldos de la base (`.bak`, `.trn`) | Carpeta de respaldos y copia fuera del sitio | Confidencial (contienen todo lo anterior) | Líder de TI | DBA |
| Código fuente | Repositorio GitHub | Interna | Líder de TI | Desarrolladores |

Toda información nueva se clasifica al crearla; si no está clasificada, se trata como **Interna**.

## 3. Control de acceso a los datos

### 3.1 Implementado

- **Acceso solo por procedimientos almacenados:** los roles `rol_digitador` y `rol_consulta` tienen `DENY SELECT, INSERT, UPDATE, DELETE` sobre los esquemas `facturacion` y `auditoria`; solo pueden ejecutar los procedimientos que su función necesita (`propi_despliegue.sql (sección 14)`). La aplicación nunca envía SQL directo.
- **Roles con mínimo privilegio** (REQ 004 y 008):

| Rol | Puede | No puede |
|---|---|---|
| `rol_administrador` | Todo sobre `facturacion`; lectura y procedimientos de `auditoria` | Modificar bitácoras |
| `rol_digitador` | Consultar, insertar y actualizar clientes; registrar facturas y notas; consultar productos e impuestos | Eliminar registros, modificar facturas, cambiar productos o impuestos (DENY) |
| `rol_consulta` | Los 4 reportes | Cualquier escritura (DENY) |

- **Login técnico sin permisos sobre datos:** `propi_app` solo puede suplantar (`IMPERSONATE`) a los usuarios de la aplicación. En cada petición el backend ejecuta `EXECUTE AS USER` → procedimiento → `REVERT`, así SQL Server aplica los permisos del rol real y los triggers registran al usuario real.

### 3.2 Reglas

1. Ningún usuario de la aplicación recibe permisos directos sobre tablas; los permisos se otorgan a roles, nunca a usuarios individuales.
2. Los cambios de permisos se hacen solo modificando `propi_despliegue.sql (sección 14)` en el repositorio (con revisión de otro integrante) y ejecutándolo; así queda historial.
3. `sysadmin` se limita al DBA y a su suplente, con cuentas nominales (no se usa `sa`, que debe estar deshabilitado en producción).
4. El acceso a los respaldos y a los archivos de llaves se limita a la cuenta del servicio de SQL Server y al DBA.

## 4. Seguridad en reposo

### 4.1 Implementado

- **Cifrado columnar AES-256** de identificación, correo y teléfono (`propi_despliegue.sql (sección 4)`, REQ 006), con la jerarquía: Service Master Key → Database Master Key → certificado `cert_clientes` → llave simétrica `llave_clientes`. Solo los procedimientos descifran con `DECRYPTBYKEY`.
- **Hash SHA2_256** de la identificación para validar duplicados sin descifrar.
- **Bitácoras separadas** en el filegroup `FG_AUDITORIA`.

### 4.2 Gestión de llaves

| Elemento | Custodio | Respaldo | Rotación |
|---|---|---|---|
| Service Master Key (instancia) | DBA | `BACKUP SERVICE MASTER KEY` al instalar y tras cambiar la cuenta del servicio | No se rota salvo compromiso |
| Database Master Key | DBA | `pa_respaldar 'LLAVES'` mensual y tras cualquier cambio (`propi_despliegue.sql (sección 16)`) | Anual, con `ALTER MASTER KEY REGENERATE` |
| Certificado `cert_clientes` y su llave privada | DBA | Igual que la master key | Anual: crear certificado nuevo, `ALTER SYMMETRIC KEY ... ADD ENCRYPTION BY CERTIFICATE` con el nuevo y luego `DROP ENCRYPTION` del anterior |
| Llave simétrica `llave_clientes` | DBA | Viaja dentro de la base | Si se compromete: crear una nueva, volver a cifrar las columnas y borrar la anterior |
| Contraseñas de la master key y de los archivos de llaves | Líder de TI | Gestor de contraseñas de la empresa y sobre sellado en caja fuerte | Al rotar la llave y cuando sale una persona que las conocía |

Reglas:

1. Los archivos de llaves se guardan separados de los respaldos de la base en la copia fuera del sitio: quien obtenga un respaldo no debe obtener también la llave.
2. Ninguna contraseña de llaves se escribe en el repositorio en producción; los scripts del proyecto usan contraseñas de ejemplo que se cambian al instalar.
3. Toda rotación se prueba primero en una base restaurada (`anexos/03_restauracion_prueba.sql`).

### 4.3 Para producción

- Activar **TDE** (Transparent Data Encryption) para cifrar también los archivos `.mdf`, `.ndf`, `.ldf` y los respaldos completos.
- Cifrar los respaldos (`BACKUP ... WITH ENCRYPTION`) con un certificado del servidor.
- Disco del servidor cifrado (BitLocker).

## 5. Seguridad en tránsito

### 5.1 Implementado

- La conexión del backend a SQL Server va cifrada con TLS (`encrypt=true` en la cadena JDBC).
- El login genera un JWT firmado con un secreto de al menos 32 bytes que expira a las 8 horas.

### 5.2 Política para producción

1. **HTTPS obligatorio** entre navegador y backend con un certificado digital de una autoridad reconocida; HTTP redirige a HTTPS y se activa HSTS.
2. **TLS 1.2 o superior** en el servidor web y en SQL Server (`Force Encryption = Yes`); TLS 1.0/1.1 y SSL deshabilitados.
3. `trustServerCertificate=false` en la cadena JDBC: SQL Server usa un certificado válido emitido para su nombre.
4. **VPN** para administrar el servidor de base de datos; el puerto 1433 no se expone a Internet y el firewall solo lo abre al servidor del backend y a la red de administración.
5. CORS del backend limitado al dominio del frontend.
6. El secreto JWT y las contraseñas de conexión viven en variables de entorno o un almacén de secretos, nunca en el repositorio.

## 6. Ciclo de vida de identidades

### 6.1 Implementado

- Un login de SQL Server por usuario, asociado a un rol; la contraseña la valida SQL Server.
- Los logins se crean sin `CHECK_POLICY = OFF`, así que aplican la política de contraseñas de Windows.

### 6.2 Altas

1. El jefe del área solicita el acceso indicando el rol; el dueño de la información lo aprueba.
2. El DBA crea el login con `CHECK_POLICY = ON` y `CHECK_EXPIRATION = ON`, el usuario en la base y lo agrega **solo** al rol aprobado.
3. La contraseña inicial se entrega por un canal distinto al del usuario y se cambia en el primer ingreso (`MUST_CHANGE`).

### 6.3 Cambios

- Un cambio de puesto implica quitar el rol anterior antes de agregar el nuevo.
- Los permisos temporales tienen fecha de vencimiento y se registran.

### 6.4 Bajas

- El mismo día de la salida: `ALTER LOGIN ... DISABLE` y cierre de sus sesiones. A los 90 días se borran el usuario y el login (las bitácoras conservan el nombre).
- Si la persona conocía contraseñas compartidas o de llaves, se cambian.

### 6.5 Política de contraseñas

- Mínimo 12 caracteres con mayúsculas, minúsculas, números y símbolos.
- Cambio cada 90 días; no se repiten las últimas 5.
- Bloqueo tras 5 intentos fallidos (política de cuentas de Windows aplicada por `CHECK_POLICY`).
- Prohibido compartir cuentas; cada persona usa la suya.

### 6.6 Revisión de permisos

- **Trimestral:** el oficial de seguridad ejecuta `facturacion.pa_rpt_seguridad` y lo revisa con cada dueño de información. Todo permiso que no se justifique se revoca.
- Se verifica que no haya usuarios sin rol, logins sin uso en 60 días ni permisos directos a usuarios.

## 7. Monitoreo y auditoría

### 7.1 Implementado

- **Bitácora de accesos** (`auditoria.bitacora_acceso`): usuario, terminal, IP, hora de ingreso y de salida (REQ 003).
- **39 triggers** (3 por tabla) escriben cada inserción, modificación y borrado en `auditoria.bitacora_auditoria` con el usuario real, la sesión y los datos en JSON (REQ 005).
- **Reportes:** pistas de auditoría (`pa_rpt_auditoria`) y configuración de seguridad (`pa_rpt_seguridad`).

### 7.2 Revisión

| Qué | Quién | Frecuencia |
|---|---|---|
| Accesos fuera de horario, desde IP desconocidas o muchos ingresos seguidos | Oficial de seguridad | Diaria (reporte automático) |
| Borrados y modificaciones de facturas, notas y clientes | Oficial de seguridad con el gerente financiero | Semanal |
| Cambios en productos, impuestos y catálogos | Líder de TI | Mensual |
| Permisos y roles | Oficial de seguridad | Trimestral |
| Errores de inicio de sesión en el log de SQL Server | DBA | Diaria |

### 7.3 Conservación

- Bitácoras de auditoría y de accesos: **5 años** en línea, como los registros contables; después se archivan en un respaldo de solo lectura.
- Respaldos: ver DRP (REQ 013).
- Nadie, ni el administrador, puede modificar o borrar registros de las bitácoras desde la aplicación; el `rol_administrador` solo tiene lectura sobre `auditoria`.

### 7.4 Respuesta ante un acceso sospechoso

1. **Detectar y registrar:** quien lo detecta avisa al oficial de seguridad, que abre un registro del incidente.
2. **Contener:** deshabilitar el login (`ALTER LOGIN ... DISABLE`), cerrar sus sesiones y, si es el login técnico, cambiar su contraseña y reiniciar el backend.
3. **Investigar:** con las bitácoras, determinar qué datos se consultaron o modificaron y desde dónde. Se preservan copias de las bitácoras como evidencia.
4. **Recuperar:** revertir cambios desde las bitácoras o restaurar a un punto en el tiempo (DRP).
5. **Notificar:** si se vieron afectados datos personales, informar a los titulares y a la PRODHAB según la Ley 8968 y su reglamento.
6. **Mejorar:** documentar causa y acciones en un plazo de 10 días hábiles.

## 8. Otros controles

- **Desarrollo:** cambios por commits en el repositorio, sin credenciales reales en el código (`application.properties` está en `.gitignore`), revisión de otro integrante antes de aplicar scripts en producción.
- **Ambientes separados:** desarrollo y pruebas usan datos de prueba (`anexos/01_datos_prueba.sql`), nunca copias de datos reales sin enmascarar.
- **Actualizaciones:** parches de seguridad de Windows y SQL Server mensuales, probados primero en la instancia secundaria.
- **Respaldos y continuidad:** ver DRP (REQ 013), BCP (REQ 011) y réplica (REQ 014).

## 9. Cumplimiento

El incumplimiento de esta política se trata según el reglamento interno de trabajo. El oficial de seguridad verifica el cumplimiento una vez al año y presenta el resultado a la gerencia.
