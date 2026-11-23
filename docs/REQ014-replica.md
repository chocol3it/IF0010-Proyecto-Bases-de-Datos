# REQ 014 · Base secundaria con réplica

## 1. Objetivo

Mantener una segunda copia de `PropiFacturacion_AAMM` casi en tiempo real y poder seguir trabajando con ella si cae la principal:

- **RPO ≤ 60 segundos:** datos que se pueden perder.
- **RTO ≤ 5 minutos:** tiempo para volver a operar.

## 2. Técnica elegida: log shipping

| Técnica | Por qué sí o no |
|---|---|
| **Log shipping** (elegida) | Usa los mismos respaldos de log del DRP (REQ 013), no exige cambios al modelo y la secundaria se puede consultar en modo STANDBY. Con respaldos de log cada 30 segundos (en lugar del minuto habitual) el RPO queda en 30 segundos como máximo, por debajo de los 60 |
| Replicación transaccional | Exige llave primaria en todas las tablas publicadas (`bitacora_auditoria` no la tiene), replica tabla por tabla y no copia la master key ni el certificado, que viven en la base |
| Grupo de disponibilidad sin clúster | RPO cero en modo sincrónico, pero requiere habilitar Always On en cada instancia (reinicio del servicio), endpoints y certificados entre instancias; más complejo de operar para el tamaño de Propi |

Una ventaja de log shipping para este proyecto: la secundaria es una copia física de la base completa, así que **la master key, el certificado `cert_clientes`, la llave simétrica, los usuarios, los roles y los permisos viajan solos**. Solo hay que crear los logins (que viven en el servidor) y volver a proteger la master key en la secundaria al activarla.

## 3. Arquitectura

| Elemento | Principal | Secundaria |
|---|---|---|
| Instancia | `localhost\SQLSERVERPT` (SQL Server 2025 Developer) | `localhost\SQLSERVERSJ` (SQL Server 2025 Developer) |
| Base | `PropiFacturacion_AAMM` en lectura y escritura, modelo FULL | `PropiFacturacion_AAMM` en STANDBY (solo lectura) |
| Trabajo del Agente | **Propi - Respaldo de log**: `pa_respaldar 'LOG'` cada 30 s | **Propi - Aplicar logs de la réplica**: `pa_replica_aplicar_logs` cada 15 s |
| Carpeta compartida | `C:\PropiRespaldos\` (escritura) | `C:\PropiRespaldos\` (lectura) |

En dos PCs distintas, la carpeta es un recurso compartido de red (`\\servidor\PropiRespaldos\`) con permiso de lectura para la cuenta del servicio de la secundaria; conviene que esté en la secundaria o en un tercer equipo, para que los logs sobrevivan si se pierde la principal.

Flujo:

1. Cada transacción confirmada en la principal queda en su log.
2. Cada 30 s la principal respalda el log a un archivo `.trn` nuevo.
3. Cada 15 s la secundaria restaura los `.trn` que no tiene, en orden, `WITH STANDBY`.
4. Si cae la principal, `pa_replica_activar` restaura los últimos `.trn` y hace `RECOVERY`.

## 4. Instalación

Requisitos: dos instancias de SQL Server Developer (Express no trae el Agente), autenticación mixta y la carpeta compartida con permisos para las cuentas de servicio de ambas instancias.

| Paso | Dónde | Qué |
|---|---|---|
| 1 | Principal | Scripts `00` a `11` (y opcionalmente `12` a `15`) |
| 2 | Principal | `propi_despliegue.sql (sección 15)`: modelo FULL y primer respaldo completo, diferencial, de log y de llaves |
| 3 | Principal | `propi_despliegue.sql (sección 16)`: trabajos del Agente, entre ellos el log cada 30 s |
| 4 | Principal | `anexos/04_logins_secundaria.sql`: copiar las sentencias `CREATE LOGIN` que devuelve |
| 5 | Secundaria | Ejecutar esas sentencias: crea `propi_admin`, `propi_digitador`, `propi_consulta` y `propi_app` con el mismo SID y la misma contraseña |
| 6 | Secundaria | `anexos/05_replica_secundaria.sql`: crea los procedimientos en `master`, el trabajo de cada 15 s y restaura la copia inicial en STANDBY |
| 7 | Ambas | Iniciar el servicio **Agente SQL Server** y dejarlo en inicio automático |

Comprobación en la secundaria:

```sql
SELECT name, state_desc, is_in_standby FROM sys.databases WHERE name = 'PropiFacturacion_AAMM';  -- ONLINE, 1
SELECT TOP 5 * FROM msdb.dbo.restorehistory WHERE destination_database_name = 'PropiFacturacion_AAMM' ORDER BY restore_date DESC;
```

Logins con el mismo SID en las dos instancias (resultado real):

| Login | SID (principal y secundaria) |
|---|---|
| propi_admin | `0x8C52C2D9858C464FBB70765FC517B2C9` |
| propi_app | `0x9B1A25FC57F5744D9E10D9B6E4A09A1C` |
| propi_consulta | `0x3A07E8B83927E54DBE88E4D9E367088D` |
| propi_digitador | `0x8128E8A125D3ED41A52BA7E08FA57D9D` |

## 5. Conmutación (failover)

### 5.1 Caída no planeada

| # | Quién | Acción | Tiempo estimado |
|---|---|---|---|
| 1 | DBA | Confirmar que la principal no responde | 1 min |
| 2 | DBA | En la secundaria: `EXEC master.dbo.pa_replica_activar;` (aplica los últimos logs, `RECOVERY`, protege la master key con la llave de servicio de este servidor, asigna la base por defecto a los logins y desactiva el trabajo de aplicar logs) | < 5 s |
| 3 | Backend | Cambiar `spring.datasource.url` a la secundaria y reiniciar el backend | 1 min |
| 4 | Soporte | Iniciar sesión y registrar una factura de prueba | 1 min |
| 5 | DBA | Crear en la secundaria los trabajos de respaldo (`propi_despliegue.sql (sección 16)`), que ahora es la principal | Después de volver a operar |

Ejemplo de cadena de conexión hacia la secundaria (con TCP habilitado en esa instancia, en el puerto 1434):

```properties
spring.datasource.url=jdbc:sqlserver://localhost:1434;databaseName=PropiFacturacion_AAMM;encrypt=true;trustServerCertificate=true;
```

Para no tener que cambiar el archivo, se puede usar un alias DNS (`sql-propi.empresa.local`) que se apunta a la instancia activa.

### 5.2 Cambio planeado (sin pérdida de datos)

En la principal, antes de activar la secundaria, respaldar el final del log y dejarla en restauración:

```sql
BACKUP LOG PropiFacturacion_AAMM TO DISK = N'C:\PropiRespaldos\PropiFacturacion_AAMM_log_<aaaammdd_hhmmss_mmm>.trn' WITH NORECOVERY;
```

Luego `pa_replica_activar` en la secundaria aplica ese último log y no se pierde ninguna transacción. La antigua principal queda lista para recibir logs y convertirse en la nueva secundaria.

### 5.3 Retorno

Cuando la principal se repara: se borra su copia de la base, se ejecuta `anexos/05_replica_secundaria.sql` en ella (ahora como secundaria) y, en una ventana de mantenimiento, se hace un cambio planeado (5.2) en sentido contrario.

## 6. Prueba de RPO y RTO

### 6.1 Método

`database/anexos/06_prueba_replica.ps1` automatiza la demostración:

1. Inserta un registro por segundo en la principal (`auditoria.bitacora_acceso`).
2. Hace el papel de los trabajos del Agente: respaldo de log cada 30 s en la principal y aplicación de logs cada 15 s en la secundaria.
3. Cada segundo consulta la secundaria (en STANDBY se puede leer) y mide cuánto tardó cada registro en aparecer.
4. Simula la caída: pone la base principal fuera de línea (`SET OFFLINE WITH ROLLBACK IMMEDIATE`).
5. Ejecuta `pa_replica_activar` en la secundaria.
6. Se conecta con el login técnico `propi_app`, hace `EXECUTE AS USER = 'propi_digitador'` y ejecuta un procedimiento, igual que el backend. Desde ese momento la aplicación puede operar: aquí se mide el RTO.
7. Compara el último registro de la principal con el último de la secundaria: los registros que faltan y su diferencia en tiempo son el RPO.
8. Registra una nota de débito en la secundaria con `pa_notas_insertar` para comprobar que acepta escrituras.

Se usó este script en lugar de los trabajos del Agente porque en el equipo de prueba el servicio del Agente no se podía iniciar sin permisos de administrador de Windows. Los procedimientos que se ejecutan son exactamente los mismos que llaman los trabajos.

### 6.2 Resultados (13 de noviembre de 2026)

| Medición | Prueba 1 | Prueba 2 | Objetivo |
|---|---|---|---|
| Registros insertados en la principal | 180 | 200 | — |
| Retraso de la secundaria (promedio) | 14,9 s | 14,9 s | — |
| Retraso de la secundaria (máximo) | 29,7 s | 29,7 s | — |
| Momento de la falla | Justo después de un respaldo de log | 20 s después del último respaldo de log | — |
| Registros perdidos | 0 | 20 | — |
| **RPO medido** | **0 s** | **20,3 s** | ≤ 60 s ✔ |
| Activación de la secundaria (`pa_replica_activar`) | 0,4 s | 0,4 s | — |
| **RTO medido de la base** (de la falla a un procedimiento ejecutado con `propi_app`) | **0,5 s** | **0,6 s** | ≤ 5 min ✔ |
| Escritura en la secundaria después de la conmutación | Correcta | Correcta | — |

**Lectura de los resultados:**

- El **RPO en el peor caso es de 30 s**: lo que se registró después del último respaldo de log. La prueba 2 (falla a los 20 s) perdió 20 registros, uno por segundo, como se esperaba. La prueba 1 es el mejor caso.
- El retraso de la secundaria mientras todo funciona llega a casi 30 s (un respaldo cada 30 s más la aplicación cada 15 s), pero eso no es pérdida: al activar, la secundaria aplica todos los logs que hay en la carpeta.
- La parte técnica de la conmutación tarda menos de 1 segundo. El **RTO real lo dominan las personas**: detectar la falla, decidir, cambiar la conexión del backend y reiniciarlo. Con el procedimiento de la sección 5.1, el total estimado es de unos 3 minutos, dentro de los 5.

### 6.3 Limitaciones de la prueba

- La caída se simuló poniendo la base fuera de línea, no apagando el servidor; para apagar el servicio se necesitan permisos de administrador de Windows. El resultado es equivalente: la secundaria no depende de la principal para activarse, solo de los archivos de la carpeta.
- Las dos instancias corren en la misma PC y no tienen TCP habilitado, por lo que no se midió el reinicio del backend contra la secundaria (JDBC necesita TCP). En el simulacro semestral del BCP se cronometra el proceso completo con la aplicación.

## 7. Detalles propios de Propi

- **Cifrado:** la master key viaja con la base pero está protegida por la llave de servicio de la principal. `pa_replica_activar` la abre con su contraseña y ejecuta `ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY`; desde ahí los procedimientos de clientes descifran sin cambios. El mismo paso se comprobó en la instancia secundaria durante la prueba de restauración del REQ 013, donde los datos de clientes se leyeron descifrados.
- **Logins:** `anexos/04_logins_secundaria.sql` genera `CREATE LOGIN ... WITH PASSWORD = <hash> HASHED, SID = <sid>`. Con el mismo SID, los usuarios de la base quedan enlazados sin `ALTER USER ... WITH LOGIN`, y con el mismo hash los usuarios siguen usando su contraseña.
- **Auditoría:** la bitácora de auditoría y la de accesos van dentro de la base, así que la secundaria tiene la misma historia.
- **Respaldos:** los archivos de log que alimentan la réplica son los mismos del DRP; no hay dos cadenas de log distintas que se interfieran.

## 8. Monitoreo

En la secundaria, el atraso respecto de la principal:

```sql
SELECT TOP 1 rh.restore_date AS ultima_restauracion,
       bs.backup_finish_date AS respaldo_de_la_principal,
       DATEDIFF(SECOND, bs.backup_finish_date, GETDATE()) AS atraso_segundos
FROM msdb.dbo.restorehistory rh
JOIN msdb.dbo.backupset bs ON bs.backup_set_id = rh.backup_set_id
WHERE rh.destination_database_name = 'PropiFacturacion_AAMM'
ORDER BY rh.restore_history_id DESC;
```

Si `atraso_segundos` pasa de 60, el DBA revisa el historial de los dos trabajos del Agente y el acceso a la carpeta.
