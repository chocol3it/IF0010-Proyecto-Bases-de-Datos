/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   08 - Bitácora de accesos a la aplicación (REQ 003)
   -------------------------------------------------------------
   La aplicación valida el usuario y la contraseña abriendo una
   conexión a SQL Server con esas credenciales (seguridad de SQL
   Server: Login -> User -> Role). Con esa misma conexión ejecuta
   pa_acceso_ingresar, que:
     1. averigua el rol del usuario en la base de datos,
     2. registra el ingreso en la bitácora,
     3. devuelve el código de sesión (cod_acceso) y el rol.
   El código de sesión se guarda luego en SESSION_CONTEXT para que
   los triggers lo registren en cod_sesion_usuario.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_acceso_ingresar
   Error 50004: el usuario no pertenece a ningún rol de la aplicación.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE auditoria.pa_acceso_ingresar
    @nom_terminal     VARCHAR(128),
    @des_direccion_ip VARCHAR(48)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_acceso INT;
    DECLARE @nom_rol VARCHAR(20);

    -- IS_ROLEMEMBER revisa los roles del usuario conectado
    SET @nom_rol = CASE
        WHEN IS_ROLEMEMBER('rol_administrador') = 1 THEN 'ADMINISTRADOR'
        WHEN IS_ROLEMEMBER('rol_digitador') = 1     THEN 'DIGITADOR'
        WHEN IS_ROLEMEMBER('rol_consulta') = 1      THEN 'CONSULTA'
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @nom_rol IS NULL
            THROW 50004, 'El usuario no tiene un rol asignado en la aplicación.', 1;

        INSERT INTO auditoria.bitacora_acceso (nom_usuario, nom_terminal, des_direccion_ip, fec_ingreso)
        VALUES (SUSER_SNAME(), ISNULL(@nom_terminal, HOST_NAME()), @des_direccion_ip, GETDATE());

        SET @cod_acceso = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @cod_acceso AS cod_acceso, SUSER_SNAME() AS nom_usuario, @nom_rol AS nom_rol;
END;
GO

/* ---------------------------------------------------------------
   pa_acceso_salir
   Registra la fecha y hora de salida de una sesión abierta.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE auditoria.pa_acceso_salir
    @cod_acceso INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE auditoria.bitacora_acceso
        SET fec_salida = GETDATE()
        WHERE cod_acceso = @cod_acceso AND fec_salida IS NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
