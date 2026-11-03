/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   11 - Seguridad: logins, usuarios, roles y permisos
        (REQ 003, REQ 004 y REQ 008)
   -------------------------------------------------------------
   Modelo (seguridad de SQL Server):
     LOGIN  (servidor)  -> permite conectarse a SQL Server
     USER   (base)      -> representa al login dentro de la BD
     ROLE   (base)      -> agrupa permisos; el usuario hereda los del rol

   Usuarios de la aplicación:
     propi_admin     -> rol_administrador  (acceso full)
     propi_digitador -> rol_digitador      (clientes, facturas y notas)
     propi_consulta  -> rol_consulta       (reportería)

   Login técnico de la aplicación:
     propi_app -> es el usuario del application.properties. No tiene
     permisos sobre datos: solo puede suplantar (IMPERSONATE) a los
     usuarios de la aplicación. En cada petición el backend ejecuta
     EXECUTE AS USER = '<usuario que inició sesión>' -> procedimiento
     -> REVERT, así SQL Server aplica los permisos del rol real y los
     triggers registran al usuario real.

   Las contraseñas son de ejemplo para el ambiente académico.
   Este script se puede ejecutar varias veces.
   ============================================================= */
USE master;
GO

/* ------------------------- Logins ------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_app')
    CREATE LOGIN propi_app WITH PASSWORD = 'PropiApp#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_admin')
    CREATE LOGIN propi_admin WITH PASSWORD = 'Admin#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_digitador')
    CREATE LOGIN propi_digitador WITH PASSWORD = 'Digitador#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'propi_consulta')
    CREATE LOGIN propi_consulta WITH PASSWORD = 'Consulta#2026', DEFAULT_DATABASE = PropiFacturacion_AAMM;
GO

USE PropiFacturacion_AAMM;
GO

/* ------------------------- Usuarios ------------------------- */
IF USER_ID('propi_app') IS NULL       CREATE USER propi_app FOR LOGIN propi_app;
IF USER_ID('propi_admin') IS NULL     CREATE USER propi_admin FOR LOGIN propi_admin;
IF USER_ID('propi_digitador') IS NULL CREATE USER propi_digitador FOR LOGIN propi_digitador;
IF USER_ID('propi_consulta') IS NULL  CREATE USER propi_consulta FOR LOGIN propi_consulta;
GO

/* ------------------------- Roles (REQ 004) ------------------------- */
IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL CREATE ROLE rol_administrador;
IF DATABASE_PRINCIPAL_ID('rol_digitador') IS NULL     CREATE ROLE rol_digitador;
IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL      CREATE ROLE rol_consulta;
GO

ALTER ROLE rol_administrador ADD MEMBER propi_admin;
ALTER ROLE rol_digitador     ADD MEMBER propi_digitador;
ALTER ROLE rol_consulta      ADD MEMBER propi_consulta;
GO

/* =================== Permisos (REQ 008) ===================
   1. REVOKE: se limpian los permisos anteriores de los roles
      (REVOKE quita tanto un GRANT como un DENY), así el script
      siempre deja la configuración exacta.
   2. GRANT: se otorga lo que cada rol necesita.
   3. DENY: se niega explícitamente lo que el rol no debe hacer.
      DENY tiene prioridad sobre cualquier GRANT.
   ========================================================== */

/* -------- 1. REVOKE: limpiar -------- */
REVOKE SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::facturacion FROM rol_administrador, rol_digitador, rol_consulta;
REVOKE SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::auditoria   FROM rol_administrador, rol_digitador, rol_consulta;
GO

/* -------- 2. GRANT -------- */

-- Login técnico: solo puede suplantar a los usuarios de la aplicación
GRANT IMPERSONATE ON USER::propi_admin     TO propi_app;
GRANT IMPERSONATE ON USER::propi_digitador TO propi_app;
GRANT IMPERSONATE ON USER::propi_consulta  TO propi_app;

-- Todos los roles: registrar su ingreso y salida (REQ 003)
GRANT EXECUTE ON auditoria.pa_acceso_ingresar TO rol_administrador, rol_digitador, rol_consulta;
GRANT EXECUTE ON auditoria.pa_acceso_salir    TO rol_administrador, rol_digitador, rol_consulta;

-- Todos los roles leen datos cifrados de clientes (REQ 006):
-- para abrir la llave simétrica se necesita ver la llave y
-- controlar el certificado que la protege.
GRANT VIEW DEFINITION ON SYMMETRIC KEY::llave_clientes TO rol_administrador, rol_digitador, rol_consulta;
GRANT CONTROL ON CERTIFICATE::cert_clientes            TO rol_administrador, rol_digitador, rol_consulta;

-- Administrador: acceso full a toda la información
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::facturacion TO rol_administrador;
GRANT SELECT, EXECUTE ON SCHEMA::auditoria TO rol_administrador;

-- Digitador: ingreso de clientes, registro de facturas y notas
GRANT EXECUTE ON facturacion.pa_clientes_consultar         TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_clientes_insertar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_clientes_actualizar        TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_consultar         TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_detalle_consultar TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_facturas_insertar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_consultar            TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_insertar             TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_notas_actualizar           TO rol_digitador;
-- para armar las facturas necesita ver productos e impuestos (solo lectura)
GRANT EXECUTE ON facturacion.pa_productos_consultar        TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_impuesto_consultar   TO rol_digitador;
-- listas de los formularios
GRANT EXECUTE ON facturacion.pa_estados_listar              TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_identificacion_listar TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_condiciones_venta_listar    TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_medios_pago_listar          TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_monedas_listar              TO rol_digitador;
GRANT EXECUTE ON facturacion.pa_tipos_nota_listar           TO rol_digitador;

-- Consulta: reportería
GRANT EXECUTE ON facturacion.pa_rpt_clientes  TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_facturas  TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_auditoria TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_rpt_seguridad TO rol_consulta;
GRANT EXECUTE ON facturacion.pa_estados_listar TO rol_consulta;
GO

/* -------- 3. DENY -------- */

-- Digitador y consulta nunca tocan las tablas directamente: solo por
-- procedimientos. (Los procedimientos sí pueden leerlas gracias al
-- encadenamiento de propiedad: tabla y procedimiento son de dbo.)
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::facturacion TO rol_digitador, rol_consulta;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::auditoria   TO rol_digitador, rol_consulta;

-- El digitador no puede borrar ni modificar el catálogo de productos e impuestos
DENY EXECUTE ON facturacion.pa_clientes_eliminar         TO rol_digitador;
DENY EXECUTE ON facturacion.pa_facturas_eliminar         TO rol_digitador;
DENY EXECUTE ON facturacion.pa_facturas_actualizar       TO rol_digitador;
DENY EXECUTE ON facturacion.pa_notas_eliminar            TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_insertar        TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_actualizar      TO rol_digitador;
DENY EXECUTE ON facturacion.pa_productos_eliminar        TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_insertar   TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_actualizar TO rol_digitador;
DENY EXECUTE ON facturacion.pa_tipos_impuesto_eliminar   TO rol_digitador;

-- El usuario de consulta no puede ejecutar ninguna operación de escritura
DENY EXECUTE ON facturacion.pa_clientes_insertar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_clientes_actualizar TO rol_consulta;
DENY EXECUTE ON facturacion.pa_clientes_eliminar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_facturas_insertar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_facturas_eliminar   TO rol_consulta;
DENY EXECUTE ON facturacion.pa_notas_insertar      TO rol_consulta;
DENY EXECUTE ON facturacion.pa_notas_eliminar      TO rol_consulta;
GO
