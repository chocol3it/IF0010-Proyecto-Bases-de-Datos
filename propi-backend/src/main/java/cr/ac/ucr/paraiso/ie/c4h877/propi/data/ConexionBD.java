package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.security.UsuarioSesion;
import java.sql.Connection;
import java.util.function.Function;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/*
 * Ejecuta los procedimientos almacenados COMO el usuario que inició sesión.
 *
 * La aplicación se conecta con el login técnico propi_app (application.properties),
 * que no tiene permisos sobre los datos. En cada petición, sobre la misma conexión:
 *   1. guarda el código de sesión en SESSION_CONTEXT (lo leen los triggers),
 *   2. EXECUTE AS USER = '<usuario>'  -> SQL Server aplica los permisos de su rol,
 *   3. ejecuta el procedimiento,
 *   4. REVERT                         -> la conexión vuelve a ser propi_app.
 * Si el rol no tiene permiso, SQL Server responde con el error 229.
 */
@Component
public class ConexionBD {

    private final JdbcTemplate jdbcTemplate;

    public ConexionBD(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public <T> T ejecutar(Function<JdbcTemplate, T> accion) {
        UsuarioSesion sesion = (UsuarioSesion) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        return jdbcTemplate.execute((ConnectionCallback<T>) (Connection conexion) -> {
            // JdbcTemplate que usa siempre esta misma conexión
            JdbcTemplate jdbc = new JdbcTemplate(new SingleConnectionDataSource(conexion, true));

            jdbc.execute("EXEC sp_set_session_context @key = N'cod_sesion', @value = " + sesion.codSesion());
            // El usuario viene del token firmado por el backend; se escapan comillas por seguridad
            jdbc.execute("EXECUTE AS USER = '" + sesion.usuario().replace("'", "''") + "'");
            try {
                return accion.apply(jdbc);
            } finally {
                jdbc.execute("REVERT");
                jdbc.execute("EXEC sp_set_session_context @key = N'cod_sesion', @value = NULL");
            }
        });
    }
}
