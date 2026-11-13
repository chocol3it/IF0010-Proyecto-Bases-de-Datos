# REQ 011 · Plan de continuidad del negocio (BCP)

## 1. Propósito y alcance

Este plan define qué hace Propi para seguir facturando cuando ocurre un evento grave: caída del servidor de base de datos, falla de red, ataque informático, pérdida del sitio o ausencia de una persona clave.

Cubre el sistema de facturación Propi completo: base de datos `PropiFacturacion_AAMM` en SQL Server, backend Spring Boot, frontend Angular y las personas que lo operan. La parte técnica de recuperar la base de datos se detalla en el DRP (REQ 013); la base secundaria, en el REQ 014.

Marco de referencia: ISO 22301 (sistemas de gestión de continuidad del negocio) y NIST SP 800-34 Rev. 1 (planes de contingencia para sistemas de información).

## 2. Análisis de impacto en el negocio (BIA)

### 2.1 Procesos críticos

| Prioridad | Proceso | Qué pasa si se detiene | Impacto | RTO | RPO |
|---|---|---|---|---|---|
| 1 | Facturación y notas de crédito/débito | No se pueden emitir comprobantes; se detienen cobros y se incumple la obligación de facturar ante Hacienda | Financiero, legal y reputacional: alto | ≤ 5 minutos | ≤ 60 segundos |
| 2 | Registro y actualización de clientes | No se pueden facturar clientes nuevos | Financiero: medio | ≤ 5 minutos (misma base) | ≤ 60 segundos |
| 3 | Reportería (clientes, facturas) | Se retrasa el control gerencial y contable | Operativo: bajo | ≤ 4 horas | ≤ 60 segundos |
| 4 | Auditoría y bitácoras de acceso | Se pierde trazabilidad mientras dure la caída | Cumplimiento: medio | ≤ 24 horas | ≤ 60 segundos |

- **RTO** (Recovery Time Objective): tiempo máximo que el proceso puede estar detenido.
- **RPO** (Recovery Point Objective): cantidad máxima de datos, medida en tiempo, que se puede perder.

Los cuatro procesos usan la misma base de datos, así que el RTO y el RPO de la base son los del proceso más crítico: **RTO ≤ 5 minutos y RPO ≤ 60 segundos**, los mismos del REQ 014. Reportería y auditoría tienen un RTO mayor porque se pueden posponer, pero sus datos se recuperan con la misma base.

### 2.2 Recursos de los que dependen

| Recurso | Procesos que lo usan | Alternativa |
|---|---|---|
| Servidor SQL Server principal | Todos | Instancia secundaria con log shipping (REQ 014) |
| Master key y certificado `cert_clientes` | Clientes, facturas, reportes (datos cifrados) | Respaldo de llaves en la carpeta de respaldos y copia fuera del sitio |
| Servidor de aplicación (backend) | Todos | Reinstalación desde el repositorio y `application.properties` respaldado |
| Red interna y acceso a Internet | Todos los usuarios | Conexión de respaldo (datos móviles) y VPN |
| Personal de TI (administrador de base de datos) | Recuperación técnica | Matriz de sucesión |

### 2.3 Escenarios de riesgo

| Escenario | Probabilidad | Impacto | Estrategia |
|---|---|---|---|
| Caída del servidor principal (hardware, sistema operativo, servicio de SQL Server) | Media | Alto | E1 |
| Corrupción de datos o borrado accidental | Baja | Alto | E2 |
| Ransomware o ataque que cifra o daña la base | Baja | Muy alto | E2 + E5 |
| Pérdida o daño de la llave de cifrado | Baja | Alto | E3 |
| Pérdida del sitio (incendio, inundación, corte eléctrico prolongado) | Muy baja | Muy alto | E4 |
| Ausencia del administrador de base de datos | Media | Medio | Matriz de sucesión |

## 3. Estructura de respuesta

### 3.1 Equipo de crisis (decide)

| Rol | Responsabilidad |
|---|---|
| Gerente general (líder de crisis) | Declara la contingencia, aprueba la conmutación al sitio o servidor alterno y autoriza la comunicación externa |
| Gerente financiero | Evalúa el impacto en facturación y cobros; coordina con contabilidad y Hacienda |
| Líder de TI | Evalúa la falla técnica y recomienda la estrategia; enlace entre el equipo de crisis y el operativo |

### 3.2 Equipo operativo (ejecuta)

| Rol | Responsabilidad |
|---|---|
| Administrador de base de datos (DBA) | Ejecuta la conmutación a la secundaria, las restauraciones y la recuperación de llaves (REQ 013 y 014) |
| Desarrollador backend | Cambia la conexión del backend a la instancia activa, reinicia la aplicación y verifica el login |
| Soporte a usuarios | Informa al personal, recibe reportes de fallas y confirma que se puede facturar |
| Oficial de seguridad | En incidentes de seguridad: contención, preservación de evidencia y revisión de bitácoras |

### 3.3 Matriz de sucesión

| Rol | Titular | Primer suplente | Segundo suplente |
|---|---|---|---|
| Líder de crisis | Gerente general | Gerente financiero | Líder de TI |
| Líder de TI | Líder de TI | DBA | Desarrollador backend |
| DBA | DBA | Desarrollador backend | Proveedor externo de soporte SQL Server |
| Desarrollador backend | Desarrollador backend | DBA | Desarrollador frontend |
| Soporte a usuarios | Soporte | Desarrollador frontend | Asistente administrativo |

Cada suplente tiene acceso a la documentación (README, DRP y este plan), a las credenciales en el gestor de contraseñas de la empresa y recibe la capacitación de la sección 6.

### 3.4 Activación

1. Cualquier persona que detecte la falla avisa a Soporte o al Líder de TI.
2. El Líder de TI evalúa en un máximo de 2 minutos si es una falla recuperable en el sitio o si se activa el plan.
3. Si la base de datos no responde, el DBA inicia la estrategia E1 sin esperar la reunión del equipo de crisis (el RTO es de 5 minutos); el Líder de TI informa al líder de crisis en paralelo.
4. El líder de crisis declara la contingencia y autoriza la comunicación.
5. Al resolverse, el líder de crisis declara el fin de la contingencia y se hace el retorno a la normalidad (sección 4.6).

## 4. Estrategias de recuperación

### E1 · Caída del servidor principal

Objetivo: RTO ≤ 5 minutos, RPO ≤ 60 segundos.

1. El DBA confirma que la instancia principal no responde.
2. Ejecuta `EXEC master.dbo.pa_replica_activar;` en la instancia secundaria. Aplica los últimos respaldos de log, deja la base en lectura y escritura y vuelve a proteger la master key (`20_replica_secundaria.sql`).
3. El desarrollador backend cambia `spring.datasource.url` a la instancia secundaria y reinicia el backend.
4. Soporte confirma con un usuario que puede iniciar sesión y emitir una factura.
5. Pérdida máxima: lo registrado después del último respaldo de log (cada 30 segundos).

### E2 · Corrupción de datos, borrado accidental o ransomware

La réplica no protege en estos casos, porque copia también el daño. Se restaura desde los respaldos (DRP, REQ 013):

1. Se detiene el ingreso de datos (se desactiva el login de la aplicación o se pone la base en modo restringido).
2. Se identifica el momento previo al daño con la bitácora de auditoría (`facturacion.pa_rpt_auditoria`).
3. El DBA restaura completo + diferencial + logs hasta ese momento (`STOPAT`) en una base nueva con `18_restauracion_prueba.sql` y verifica los datos.
4. Se reemplaza la base dañada o se copian los registros afectados.
5. En ransomware: antes de restaurar, el oficial de seguridad aísla el servidor y se restaura en un servidor limpio; se usan las copias fuera del sitio si las locales también fueron afectadas.

### E3 · Pérdida de la llave de cifrado

Sin la master key y el certificado `cert_clientes`, la identificación, el correo y el teléfono de los clientes no se pueden leer.

1. El DBA restaura la master key desde su respaldo (`RESTORE MASTER KEY ... FORCE`) o el certificado (`CREATE CERTIFICATE ... FROM FILE ... WITH PRIVATE KEY`).
2. Las contraseñas de los archivos de llaves están en el gestor de contraseñas y una copia en sobre sellado en la caja fuerte de gerencia.
3. Se verifica que los procedimientos de clientes descifran correctamente.

### E4 · Pérdida del sitio

1. Se instala SQL Server en el sitio alterno (otra oficina o un servidor en la nube) con la guía del README.
2. Se restauran la base y las llaves desde la copia fuera del sitio (DRP, REQ 013).
3. Se crean los logins con el script `19_logins_secundaria.sql` (mismos SID).
4. Se despliega el backend y el frontend desde el repositorio de GitHub.
5. RTO de este escenario: hasta 8 horas. RPO: el de la última copia fuera del sitio (diaria, máximo 24 horas; con los logs sincronizados a la nube, 15 minutos).

### E5 · Ataque o acceso sospechoso

1. Contención: se deshabilita el login comprometido (`ALTER LOGIN ... DISABLE`) y se cierran sus sesiones.
2. Se revisan la bitácora de accesos y la de auditoría para ver qué se consultó o modificó.
3. Se cambian las contraseñas afectadas y, si hubo acceso a datos personales, se aplica el procedimiento de notificación de la política de seguridad (REQ 012, Ley 8968).

### 4.6 Retorno a la normalidad

1. Se repara el servidor principal.
2. Se reconstruye la réplica en sentido contrario o se vuelve a la configuración original en una ventana de mantenimiento: respaldo completo de la base activa, restauración en el servidor reparado y conmutación planeada (con respaldo del final del log, sin pérdida de datos).
3. Se documenta el incidente: causa, tiempos reales de RTO y RPO, y mejoras.

### 4.7 Operación manual mínima

Si ninguna estrategia técnica funciona dentro del RTO, las facturas urgentes se emiten con la herramienta gratuita de facturación electrónica del Ministerio de Hacienda y se registran después en Propi como facturas con su número de referencia.

## 5. Comunicación de crisis

| A quién | Cuándo | Canal | Responsable | Mensaje |
|---|---|---|---|---|
| Personal de Propi | Al declarar la contingencia y al terminarla | Grupo de mensajería interno y correo | Soporte | "El sistema de facturación está en recuperación. Tiempo estimado: X minutos. No emitan facturas en papel; esperen la confirmación." |
| Equipo de crisis | Inmediatamente | Llamada telefónica | Líder de TI | Descripción de la falla, estrategia activada y tiempo estimado |
| Clientes | Si la interrupción supera 30 minutos o afecta facturas ya emitidas | Correo y redes sociales | Gerente general | "Estamos atendiendo una falla técnica. Sus facturas y datos están protegidos. Le enviaremos sus comprobantes en cuanto se restablezca el servicio." |
| Ministerio de Hacienda | Si no se pueden emitir comprobantes electrónicos en el plazo legal | Canal oficial de la Dirección General de Tributación | Gerente financiero | Notificación de contingencia según la normativa de comprobantes electrónicos |
| Agencia de Protección de Datos de los Habitantes (PRODHAB) y titulares afectados | Si hubo acceso no autorizado a datos personales | Nota formal y correo a los afectados | Gerente general y oficial de seguridad | Qué datos se vieron afectados, medidas tomadas y recomendaciones (Ley 8968 y su reglamento) |

Reglas: un único vocero externo (gerente general); los mensajes no incluyen detalles técnicos que faciliten un ataque; se lleva una bitácora de cada comunicación con fecha y hora.

### Lista de contactos

Se mantiene en el gestor de contraseñas y en una copia impresa en la caja fuerte: teléfonos del equipo de crisis, equipo operativo, suplentes, proveedor de Internet, proveedor de soporte de SQL Server y contacto de Hacienda. Se actualiza cada vez que cambia el personal.

## 6. Mantenimiento, pruebas y capacitación

### 6.1 Revisión del plan

- Cada 6 meses, o antes si cambia la arquitectura, el personal clave o después de un incidente.
- Responsable: Líder de TI. Aprueba: Gerente general.
- Cada versión se registra en el control de versiones del documento final.

### 6.2 Calendario de pruebas

| Prueba | Frecuencia | Qué se mide | Responsable |
|---|---|---|---|
| Verificación de respaldos (`RESTORE VERIFYONLY` automático) | Cada respaldo | Que el archivo se pueda leer | DBA |
| Restauración en base de prueba (`18_restauracion_prueba.sql`) | Mensual | Que la cadena completa se restaura y los datos cifrados se leen | DBA |
| Revisión de latencia de la réplica | Semanal | Que la secundaria no se atrase más de 60 segundos | DBA |
| Simulacro de conmutación a la secundaria | Cada semestre | RTO ≤ 5 min y RPO ≤ 60 s reales | DBA, backend y soporte |
| Restauración de llaves desde archivo | Anual | Que los archivos y contraseñas de las llaves funcionan | DBA |
| Ejercicio de escritorio con el equipo de crisis | Anual | Que cada rol conoce sus pasos y contactos | Líder de TI |

Cada prueba deja un acta con fecha, participantes, tiempos medidos, problemas y acciones de mejora.

### 6.3 Capacitación

| Quién | Contenido | Frecuencia |
|---|---|---|
| DBA y suplentes | Conmutación, restauración, recuperación de llaves, logins con SID | Semestral, en el simulacro |
| Desarrolladores | Cambio de conexión del backend y despliegue desde el repositorio | Semestral |
| Equipo de crisis | Activación del plan, comunicación y obligaciones legales | Anual |
| Todo el personal | Qué hacer y a quién avisar ante una caída; procedimiento de operación manual | Anual y al ingresar a la empresa |
