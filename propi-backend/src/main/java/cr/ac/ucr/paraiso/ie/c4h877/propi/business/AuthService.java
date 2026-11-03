package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.ConexionBD;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginRespuestaDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.security.JwtTokenProvider;
import cr.ac.ucr.paraiso.ie.c4h877.propi.security.UsuarioSesion;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    // 18456 = "Login failed for user" en SQL Server
    private static final int LOGIN_FALLIDO = 18456;

    private final String urlBaseDatos;
    private final JwtTokenProvider tokenProvider;
    private final ConexionBD conexionBD;

    public AuthService(@Value("${spring.datasource.url}") String urlBaseDatos,
            JwtTokenProvider tokenProvider, ConexionBD conexionBD) {
        this.urlBaseDatos = urlBaseDatos;
        this.tokenProvider = tokenProvider;
        this.conexionBD = conexionBD;
    }

    /*
     * REQ 003: quien valida el usuario y la contraseña es SQL Server.
     * Se abre una conexión con las credenciales digitadas; si SQL Server la acepta,
     * con esa misma conexión se registra el ingreso en la bitácora y se obtiene el rol.
     */
    public LoginRespuestaDTO login(LoginDTO datos, String terminal, String ip) {
        try (Connection conexion = DriverManager.getConnection(urlBaseDatos, datos.usuario(), datos.contrasena())) {
            JdbcTemplate jdbc = new JdbcTemplate(new SingleConnectionDataSource(conexion, true));

            UsuarioSesion sesion = jdbc.queryForObject("EXEC auditoria.pa_acceso_ingresar ?, ?",
                    (rs, fila) -> new UsuarioSesion(rs.getString("nom_usuario"), rs.getString("nom_rol"),
                            rs.getInt("cod_acceso")),
                    terminal, ip);

            return new LoginRespuestaDTO(tokenProvider.generarToken(sesion), sesion.usuario(), sesion.rol());
        } catch (SQLException exception) {
            if (exception.getErrorCode() == LOGIN_FALLIDO) {
                throw new BadCredentialsException("Usuario o contraseña incorrectos.");
            }
            throw new IllegalStateException("No se pudo conectar a la base de datos: " + exception.getMessage());
        }
    }

    // Registra la fecha y hora de salida en la bitácora de accesos
    public void logout() {
        UsuarioSesion sesion = (UsuarioSesion) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC auditoria.pa_acceso_salir ?", sesion.codSesion()));
    }
}
