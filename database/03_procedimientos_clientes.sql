/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   03 - Procedimientos almacenados: CRUD de Clientes (REQ 002)
   -------------------------------------------------------------
   La aplicación nunca escribe SQL directo sobre las tablas: todo
   pasa por procedimientos con parámetros, lo que evita el SQL
   Injection. Los que modifican datos usan TRY/CATCH y una
   transacción explícita: si algo falla se hace ROLLBACK y el
   error se devuelve a la aplicación con THROW.
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

    SELECT cod_cliente, nom_cliente, cod_tipo_identificacion, num_identificacion,
           des_provincia, des_canton, des_distrito, des_barrio, des_profesion,
           des_actividad_economica, des_correo, num_telefono, fec_registro, cod_estado
    FROM facturacion.clientes
    WHERE @cod_cliente IS NULL OR cod_cliente = @cod_cliente
    ORDER BY nom_cliente;
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

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND num_identificacion = @num_identificacion)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        INSERT INTO facturacion.clientes
            (nom_cliente, cod_tipo_identificacion, num_identificacion, des_provincia, des_canton,
             des_distrito, des_barrio, des_profesion, des_actividad_economica, des_correo,
             num_telefono, cod_estado)
        VALUES
            (@nom_cliente, @cod_tipo_identificacion, @num_identificacion, @des_provincia, @des_canton,
             @des_distrito, @des_barrio, @des_profesion, @des_actividad_economica, @des_correo,
             @num_telefono, @cod_estado);

        SET @cod_cliente = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

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

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM facturacion.clientes WHERE cod_cliente = @cod_cliente)
            THROW 50002, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM facturacion.clientes
                   WHERE cod_tipo_identificacion = @cod_tipo_identificacion
                     AND num_identificacion = @num_identificacion
                     AND cod_cliente <> @cod_cliente)
            THROW 50001, 'Ya existe un cliente con esa identificación.', 1;

        UPDATE facturacion.clientes
        SET nom_cliente             = @nom_cliente,
            cod_tipo_identificacion = @cod_tipo_identificacion,
            num_identificacion      = @num_identificacion,
            des_provincia           = @des_provincia,
            des_canton              = @des_canton,
            des_distrito            = @des_distrito,
            des_barrio              = @des_barrio,
            des_profesion           = @des_profesion,
            des_actividad_economica = @des_actividad_economica,
            des_correo              = @des_correo,
            num_telefono            = @num_telefono,
            cod_estado              = @cod_estado
        WHERE cod_cliente = @cod_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

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

/* ---------------------------------------------------------------
   Catálogos que usa el formulario de clientes
--------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE facturacion.pa_tipos_identificacion_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_tipo_identificacion, des_tipo_identificacion
    FROM facturacion.tipos_identificacion
    ORDER BY cod_tipo_identificacion;
END;
GO

CREATE OR ALTER PROCEDURE facturacion.pa_estados_listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cod_estado, des_estado
    FROM facturacion.estados
    ORDER BY cod_estado;
END;
GO
