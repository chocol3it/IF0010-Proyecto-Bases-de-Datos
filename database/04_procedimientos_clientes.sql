/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   04 - Procedimientos almacenados: CRUD de Clientes (REQ 002)
   -------------------------------------------------------------
   La aplicación nunca escribe SQL directo sobre las tablas: todo
   pasa por procedimientos con parámetros, lo que evita el SQL
   Injection. Los que modifican datos usan TRY/CATCH y una
   transacción explícita: si algo falla se hace ROLLBACK y el
   error se devuelve a la aplicación con THROW.

   Cifrado (REQ 006): la identificación, el correo y el teléfono
   se cifran con la llave llave_clientes al guardar y se descifran
   al consultar, así la aplicación siempre los ve en texto claro.

   Errores de negocio:
     50001 registro duplicado
     50002 registro inexistente
     50003 regla de negocio
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

/* ---------------------------------------------------------------
   pa_clientes_consultar
   Devuelve un cliente (@cod_cliente) o todos si se envía NULL.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_consultar
    @cod_cliente INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    SELECT c.cod_cliente, c.nom_cliente, c.cod_tipo_identificacion, t.des_tipo_identificacion,
           CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_identificacion)) AS num_identificacion,
           c.des_provincia, c.des_canton, c.des_distrito, c.des_barrio, c.des_profesion,
           c.des_actividad_economica,
           CONVERT(VARCHAR(150), DECRYPTBYKEY(c.des_correo)) AS des_correo,
           CONVERT(VARCHAR(20), DECRYPTBYKEY(c.num_telefono)) AS num_telefono,
           c.fec_registro, c.cod_estado
    FROM facturacion.clientes c
    JOIN facturacion.tipos_identificacion t ON t.cod_tipo_identificacion = c.cod_tipo_identificacion
    WHERE @cod_cliente IS NULL OR c.cod_cliente = @cod_cliente
    ORDER BY c.nom_cliente;

    CLOSE SYMMETRIC KEY llave_clientes;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_insertar
   Registra un cliente y devuelve el registro creado.
   Error 50001: ya existe un cliente con esa identificación.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_insertar
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion INT,
    @num_identificacion      VARCHAR(20),
    @des_provincia           VARCHAR(50),
    @des_canton              VARCHAR(50),
    @des_distrito            VARCHAR(50),
    @des_barrio              VARCHAR(100),
    @des_profesion           VARCHAR(100),
    @des_actividad_economica VARCHAR(150),
    @des_correo              VARCHAR(150),
    @num_telefono            VARCHAR(20),
    @cod_estado              CHAR(1) = 'A'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cod_cliente INT;
    DECLARE @hash VARBINARY(32) = HASHBYTES('SHA2_256', @num_identificacion);

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND cod_hash_identificacion = @hash)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        INSERT INTO facturacion.clientes
            (nom_cliente, cod_tipo_identificacion, num_identificacion, cod_hash_identificacion,
             des_provincia, des_canton, des_distrito, des_barrio, des_profesion,
             des_actividad_economica, des_correo, num_telefono, cod_estado)
        VALUES
            (@nom_cliente, @cod_tipo_identificacion,
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_identificacion), @hash,
             @des_provincia, @des_canton, @des_distrito, @des_barrio, @des_profesion,
             @des_actividad_economica,
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @des_correo),
             ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_telefono),
             @cod_estado);

        SET @cod_cliente = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;

    EXEC facturacion.pa_clientes_consultar @cod_cliente;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_actualizar
   Modifica un cliente y devuelve el registro actualizado.
   Error 50002: el cliente no existe.
   Error 50001: la identificación ya pertenece a otro cliente.
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_actualizar
    @cod_cliente             INT,
    @nom_cliente             VARCHAR(150),
    @cod_tipo_identificacion INT,
    @num_identificacion      VARCHAR(20),
    @des_provincia           VARCHAR(50),
    @des_canton              VARCHAR(50),
    @des_distrito            VARCHAR(50),
    @des_barrio              VARCHAR(100),
    @des_profesion           VARCHAR(100),
    @des_actividad_economica VARCHAR(150),
    @des_correo              VARCHAR(150),
    @num_telefono            VARCHAR(20),
    @cod_estado              CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @hash VARBINARY(32) = HASHBYTES('SHA2_256', @num_identificacion);

    OPEN SYMMETRIC KEY llave_clientes DECRYPTION BY CERTIFICATE cert_clientes;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes WHERE cod_cliente = @cod_cliente)
            THROW 50002, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND cod_hash_identificacion = @hash
                     AND cod_cliente <> @cod_cliente)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        UPDATE facturacion.clientes
        SET nom_cliente             = @nom_cliente,
            cod_tipo_identificacion = @cod_tipo_identificacion,
            num_identificacion      = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_identificacion),
            cod_hash_identificacion = @hash,
            des_provincia           = @des_provincia,
            des_canton              = @des_canton,
            des_distrito            = @des_distrito,
            des_barrio              = @des_barrio,
            des_profesion           = @des_profesion,
            des_actividad_economica = @des_actividad_economica,
            des_correo              = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @des_correo),
            num_telefono            = ENCRYPTBYKEY(KEY_GUID('llave_clientes'), @num_telefono),
            cod_estado              = @cod_estado
        WHERE cod_cliente = @cod_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        CLOSE SYMMETRIC KEY llave_clientes;
        THROW;
    END CATCH;

    CLOSE SYMMETRIC KEY llave_clientes;

    EXEC facturacion.pa_clientes_consultar @cod_cliente;
END;
GO

/* ---------------------------------------------------------------
   pa_clientes_eliminar
   Borra un cliente.
   Error 50002: el cliente no existe.
   Error 50003: el cliente tiene facturas (se debe inactivar).
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_clientes_eliminar
    @cod_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes WHERE cod_cliente = @cod_cliente)
            THROW 50002, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.facturas WHERE cod_cliente = @cod_cliente)
            THROW 50003, 'El cliente tiene facturas registradas; inactívelo en lugar de borrarlo.', 1;

        DELETE FROM facturacion.clientes WHERE cod_cliente = @cod_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
