/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   05 - Prueba del avance (punto de control 1)
   -------------------------------------------------------------
   Ejecutar por bloques en SSMS para demostrar:
   CRUD por procedimientos -> triggers -> bitácora de auditoría,
   y el ROLLBACK cuando un procedimiento falla.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

-- 1. Simular la sesión que luego fijará la aplicación al hacer login
EXEC sp_set_session_context @key = N'cod_sesion', @value = 1;
GO

-- 2. Insertar
EXEC facturacion.pa_clientes_insertar
    @nom_cliente = 'María Fernández Solano', @cod_tipo_identificacion = 1,
    @num_identificacion = '301230456', @des_provincia = 'Cartago', @des_canton = 'Paraíso',
    @des_distrito = 'Paraíso', @des_barrio = 'Centro', @des_profesion = 'Ingeniera civil',
    @des_actividad_economica = 'Construcción', @des_correo = 'maria.fernandez@correo.com',
    @num_telefono = '8888-1234';
GO

-- 3. Modificar (cambia teléfono y correo)
DECLARE @id INT = (SELECT MAX(cod_cliente) FROM facturacion.clientes);
EXEC facturacion.pa_clientes_actualizar
    @cod_cliente = @id, @nom_cliente = 'María Fernández Solano', @cod_tipo_identificacion = 1,
    @num_identificacion = '301230456', @des_provincia = 'Cartago', @des_canton = 'Paraíso',
    @des_distrito = 'Paraíso', @des_barrio = 'Centro', @des_profesion = 'Ingeniera civil',
    @des_actividad_economica = 'Construcción', @des_correo = 'mfernandez@correo.com',
    @num_telefono = '8777-4321', @cod_estado = 'A';
GO

-- 4. Error controlado: identificación repetida -> ROLLBACK, no se inserta nada
EXEC facturacion.pa_clientes_insertar
    @nom_cliente = 'Duplicado', @cod_tipo_identificacion = 1,
    @num_identificacion = '301230456', @des_provincia = 'Cartago', @des_canton = 'Paraíso',
    @des_distrito = 'Paraíso', @des_barrio = NULL, @des_profesion = NULL,
    @des_actividad_economica = NULL, @des_correo = 'x@correo.com', @num_telefono = '8000-0000';
GO

-- 5. Borrar
DECLARE @id INT = (SELECT MAX(cod_cliente) FROM facturacion.clientes);
EXEC facturacion.pa_clientes_eliminar @cod_cliente = @id;
GO

-- 6. Resultado: una fila I, una U (antes/después) y una D
SELECT fec_registro, cod_guid, ind_accion, cod_usuario, cod_sesion_usuario,
       cod_tabla, cod_llave, des_datos
FROM auditoria.bitacora_auditoria
ORDER BY fec_registro;
GO
