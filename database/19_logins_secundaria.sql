--Proyecto IF0010 - Sistema de Facturación Propi
--19 - Logins para la instancia secundaria (REQ 014)
--Se ejecuta en la PRINCIPAL. Genera los CREATE LOGIN de la aplicación con el mismo SID y la
--misma contraseña (en hash), para ejecutarlos luego en la SECUNDARIA.
--Los logins viven en el servidor y no viajan con la base: si el SID no coincide, los usuarios
--de la base quedan huérfanos y nadie puede entrar después de la conmutación
--La base por defecto se asigna al activar la secundaria (20_replica_secundaria.sql)
USE master;
GO
SET NOCOUNT ON;

SELECT CONCAT(
    'IF SUSER_ID(''', name, ''') IS NULL CREATE LOGIN ', QUOTENAME(name),
    ' WITH PASSWORD = ', CONVERT(VARCHAR(512), CAST(LOGINPROPERTY(name, 'PasswordHash') AS VARBINARY(256)), 1), ' HASHED',
    ', SID = ', CONVERT(VARCHAR(100), sid, 1),
    ', CHECK_POLICY = ', CASE WHEN is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END,
    ', CHECK_EXPIRATION = ', CASE WHEN is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END, ';') AS sentencia
FROM sys.sql_logins
WHERE name LIKE 'propi[_]%'
ORDER BY name;
GO
