# REQ 013 · Política de respaldos y plan de recuperación ante desastres (DRP)

## 1. Objetivo y alcance

El DRP es el plan técnico para recuperar la base de datos `PropiFacturacion_AAMM` y los sistemas de Propi después de un desastre. Complementa el BCP (REQ 011), que cubre el negocio completo, y la base secundaria (REQ 014), que cubre la caída del servidor.

Scripts del proyecto:

| Script | Qué hace |
|---|---|
| `database/propi_despliegue.sql (sección 15)` | Pone la base en modelo de recuperación FULL, crea `dbo.pa_respaldar` (completo, diferencial, log y llaves) y hace el primer juego de respaldos |
| `database/propi_despliegue.sql (sección 16)` | Crea los trabajos del Agente SQL que programan los respaldos y la limpieza |
| `database/anexos/03_restauracion_prueba.sql` | Restaura la cadena más reciente en una base con otro nombre (o en otro servidor) y la verifica |

## 2. Objetivos de recuperación

| Escenario | RTO | RPO | Cómo se logra |
|---|---|---|---|
| Caída del servidor principal | ≤ 5 minutos | ≤ 60 segundos | Conmutación a la secundaria (REQ 014); respaldos de log cada 30 segundos |
| Corrupción, borrado accidental o ransomware | ≤ 1 hora | ≤ 60 segundos con los respaldos locales | Restauración a un punto en el tiempo desde completo + diferencial + logs |
| Pérdida del sitio | ≤ 8 horas | ≤ 24 horas (copia diaria fuera del sitio) | Restauración en el sitio alterno |

Son los mismos valores del BCP (REQ 011) y del REQ 014.

## 3. Inventario de activos

| Prioridad | Activo | Descripción | Respaldo |
|---|---|---|---|
| 1 | Base `PropiFacturacion_AAMM` | Archivo de datos `.mdf` (filegroup PRIMARY, esquema `facturacion`), `PropiFacturacion_AAMM_auditoria.ndf` (filegroup FG_AUDITORIA, bitácoras) y log `.ldf` | Completo, diferencial y log |
| 1 | Master key y certificado `cert_clientes` | Sin ellos no se leen la identificación, el correo ni el teléfono de los clientes | `pa_respaldar 'LLAVES'` (archivos `.key`, `.cer`, `.pvk` protegidos con contraseña) |
| 1 | Servidor SQL Server (instancia principal) | SQL Server 2025 Developer, modo de autenticación mixto | Reinstalación; configuración documentada en el README |
| 2 | Logins `propi_admin`, `propi_digitador`, `propi_consulta`, `propi_app` | Viven en `master`, no dentro de la base | `anexos/04_logins_secundaria.sql` genera los CREATE LOGIN con el mismo SID y hash |
| 2 | Instancia secundaria | Copia en STANDBY mantenida por log shipping (REQ 014) | Se reconstruye con `anexos/05_replica_secundaria.sql` |
| 3 | Backend Spring Boot | Código en GitHub; `application.properties` con la conexión y el secreto JWT | Repositorio + copia del archivo de configuración en el gestor de contraseñas |
| 3 | Frontend Angular | Código en GitHub | Repositorio |
| 4 | Trabajos del Agente SQL | Programación de respaldos y de la réplica | Scripts 17 y 20 |

## 4. Estrategia de respaldo

### 4.1 Tipos y frecuencia

La base está en modelo de recuperación **FULL**: el log guarda todas las transacciones hasta que se respalda, lo que permite los respaldos de log y la restauración a un punto en el tiempo.

| Tipo | Frecuencia | Trabajo del Agente | Contenido |
|---|---|---|---|
| Completo | Semanal, domingo 00:30 | Propi - Respaldo completo | Toda la base (los tres archivos) |
| Diferencial | Diario, lunes a sábado 00:30 | Propi - Respaldo diferencial | Las páginas que cambiaron desde el último completo |
| Log de transacciones | Cada 30 segundos | Propi - Respaldo de log | Las transacciones desde el último respaldo de log. Los mismos archivos alimentan la réplica del REQ 014 |
| Llaves | Mensual (día 1, 00:15) y después de cualquier cambio de llaves | Propi - Respaldo de llaves | Master key y certificado con su llave privada |

Todos los respaldos se hacen con `CHECKSUM` y se verifican con `RESTORE VERIFYONLY` al terminar (lo hace `pa_respaldar`). Los archivos llevan la fecha y hora en el nombre: `PropiFacturacion_AAMM_<tipo>_<aaaammdd_hhmmss_mmm>.<bak|trn>`.

En SQL Server Express, que no trae el Agente, los mismos `EXEC dbo.pa_respaldar ...` se programan con el Programador de tareas de Windows y `sqlcmd`.

### 4.2 Dónde se guardan

| Copia | Ubicación | Contenido |
|---|---|---|
| Local | Carpeta `C:\PropiRespaldos\` en un disco distinto al de los datos (en producción, un volumen dedicado) | Todos los respaldos |
| Réplica | Instancia secundaria | La base al día (no reemplaza a los respaldos) |
| Fuera del sitio | Almacenamiento en la nube cifrado, sincronizado cada noche (los logs, cada 15 minutos) | Completos, diferenciales y logs |
| Llaves fuera del sitio | Ubicación distinta a la de los respaldos (bóveda del gestor de contraseñas) | Archivos `.key`, `.cer` y `.pvk` |

Regla 3-2-1: al menos 3 copias, en 2 medios distintos y 1 fuera del sitio.

### 4.3 Retención

| Tipo | Local | Fuera del sitio |
|---|---|---|
| Completo | 5 semanas | 12 meses (el primero de cada mes) |
| Diferencial | 5 semanas | 1 mes |
| Log | 8 días | 1 mes |
| Llaves | Todas las versiones mientras exista algún respaldo que las necesite | Igual |

El trabajo **Propi - Limpieza de respaldos** borra cada día los `.bak` de más de 35 días y los `.trn` de más de 8 días de la carpeta local.

## 5. Procedimiento de recuperación

### 5.1 Restaurar la base (completo → diferencial → logs)

`anexos/03_restauracion_prueba.sql` hace estos pasos automáticamente con los archivos de la carpeta. Paso a paso manual:

```sql
-- 1. Si la base dañada todavía responde, respaldar el final del log para no perder nada
BACKUP LOG PropiFacturacion_AAMM TO DISK = N'C:\PropiRespaldos\final_del_log.trn' WITH NO_TRUNCATE, NORECOVERY;

-- 2. Último respaldo completo, sin recuperar
RESTORE DATABASE PropiFacturacion_AAMM
    FROM DISK = N'C:\PropiRespaldos\PropiFacturacion_AAMM_completo_<fecha>.bak'
    WITH NORECOVERY, REPLACE, CHECKSUM;

-- 3. Último diferencial posterior a ese completo
RESTORE DATABASE PropiFacturacion_AAMM
    FROM DISK = N'C:\PropiRespaldos\PropiFacturacion_AAMM_diferencial_<fecha>.bak'
    WITH NORECOVERY, CHECKSUM;

-- 4. Cada log posterior al diferencial, en orden
RESTORE LOG PropiFacturacion_AAMM FROM DISK = N'C:\PropiRespaldos\PropiFacturacion_AAMM_log_<fecha>.trn' WITH NORECOVERY;
-- ... (uno por archivo)
-- Para volver a un momento antes del daño, en los logs agregar: STOPAT = '2026-11-13T10:42:00'

-- 5. Dejar la base disponible
RESTORE DATABASE PropiFacturacion_AAMM WITH RECOVERY;
```

En otro servidor se agregan las opciones `MOVE` para ubicar los tres archivos (`PropiFacturacion_AAMM`, `PropiFacturacion_AAMM_auditoria`, `PropiFacturacion_AAMM_log`) en las carpetas de ese servidor.

### 5.2 Restaurar las llaves de cifrado

La master key viaja dentro de la base, pero protegida por la Service Master Key del servidor donde se creó. En otro servidor no se abre sola.

**Caso normal (se conoce la contraseña de la master key):**

```sql
USE PropiFacturacion_AAMM;
OPEN MASTER KEY DECRYPTION BY PASSWORD = '<contraseña de la master key>';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;   -- desde ahora se abre sola en este servidor
CLOSE MASTER KEY;
```

**Si se perdió esa contraseña o la master key está dañada:**

```sql
RESTORE MASTER KEY FROM FILE = N'C:\PropiRespaldos\PropiFacturacion_AAMM_master_key_<fecha>.key'
    DECRYPTION BY PASSWORD = '<contraseña del archivo>'
    ENCRYPTION BY PASSWORD = '<nueva contraseña>' FORCE;
OPEN MASTER KEY DECRYPTION BY PASSWORD = '<nueva contraseña>';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
```

**Si se perdió el certificado:**

```sql
CREATE CERTIFICATE cert_clientes
    FROM FILE = N'C:\PropiRespaldos\PropiFacturacion_AAMM_cert_clientes_<fecha>.cer'
    WITH PRIVATE KEY (FILE = N'C:\PropiRespaldos\PropiFacturacion_AAMM_cert_clientes_<fecha>.pvk',
                      DECRYPTION BY PASSWORD = '<contraseña del archivo>');
```

> SQL Server crea los archivos de llaves con permisos solo para la cuenta del servicio que los generó. Para usarlos en otro servidor, un administrador de Windows debe copiarlos o dar permiso de lectura a la cuenta del servicio de destino. Se comprobó en la prueba (sección 7).

### 5.3 Logins y verificación

1. Crear los logins con el mismo SID: ejecutar `anexos/04_logins_secundaria.sql` en un servidor que los tenga (o tomar la salida guardada) y correr las sentencias en el servidor nuevo.
2. Verificar:
   - `DBCC CHECKDB` sin errores.
   - Cantidad de registros de las tablas principales igual a la esperada.
   - `EXEC facturacion.pa_clientes_consultar` devuelve identificación, correo y teléfono legibles.
   - Iniciar sesión en la aplicación con cada rol.
3. Cambiar `spring.datasource.url` del backend si el servidor cambió y reiniciar.

## 6. Equipo de recuperación

| Paso | Ejecuta | Aprueba |
|---|---|---|
| Declarar el desastre y elegir el escenario | Líder de TI | Gerente general |
| Respaldo del final del log y restauración de la base | DBA (suplente: desarrollador backend) | Líder de TI |
| Restauración de llaves (requiere las contraseñas custodiadas) | DBA | Líder de TI |
| Logins y permisos | DBA | Oficial de seguridad |
| Verificación de datos | DBA con el gerente financiero | Gerente financiero |
| Reconexión del backend y prueba con usuarios | Desarrollador backend y soporte | Líder de TI |
| Cierre e informe del incidente | Líder de TI | Gerente general |

## 7. Mantenimiento y pruebas

| Prueba | Frecuencia | Responsable |
|---|---|---|
| `RESTORE VERIFYONLY` de cada respaldo | Automática | `pa_respaldar` |
| Revisión del historial de trabajos del Agente (que no haya fallos) | Diaria | DBA |
| Restauración completa en base de prueba con `anexos/03_restauracion_prueba.sql` | Mensual | DBA |
| Restauración en otro servidor, incluidas las llaves desde archivo | Semestral, junto al simulacro del BCP | DBA |
| Revisión de este plan | Semestral o tras un incidente | Líder de TI |

Cada prueba deja un acta con fecha, archivos usados, tiempos y resultado.

### Prueba realizada (13 de noviembre de 2026)

Ambiente: SQL Server 2025 Developer, instancias `SQLSERVERPT` (principal) y `SQLSERVERSJ` (otro servidor), base con los datos de prueba del REQ 009. El 23 de noviembre se volvió a desplegar con `propi_despliegue.sql` en el equipo de la defensa (principal `SQLUCR`): la sección 15 generó el primer juego de respaldos (completo, diferencial, log y llaves) y los trabajos del Agente quedaron programados.

| Paso | Resultado |
|---|---|
| `propi_despliegue.sql (sección 15)` | Respaldo completo de 19,1 MB (2 233 páginas en 0,17 s), diferencial de 2,1 MB, log y llaves; los tres verificados con `RESTORE VERIFYONLY` |
| Cambio después de los respaldos | Se insertó un registro de prueba en `bitacora_acceso` y se respaldó el log |
| `anexos/03_restauracion_prueba.sql` en la misma instancia | Completo + diferencial + 2 logs restaurados en `PropiFacturacion_AAMM_prueba`; `DBCC CHECKDB` sin errores; 1 000 clientes, 3 000 facturas, 6 000 líneas, 1 000 notas y 20 000 registros de auditoría; datos cifrados legibles; el registro insertado después del diferencial está presente |
| `anexos/03_restauracion_prueba.sql` en la instancia `SQLSERVERSJ` | Mismo resultado. La master key se abrió con su contraseña y se protegió con la Service Master Key del nuevo servidor; los datos de clientes se descifraron correctamente |
| Restauración de la master key desde el archivo `.key` | `RESTORE MASTER KEY ... FORCE` funcionó en la instancia que creó el archivo. En la otra instancia falló por permisos del archivo (ver nota de la sección 5.2) |
| Tiempo total de la restauración | Menos de 2 segundos con este volumen de datos |
