package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Cliente;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ClienteDTO;
import java.util.List;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

// Todas las operaciones son llamadas a procedimientos almacenados con parámetros (?),
// nunca SQL armado con texto: así se evita el SQL Injection (REQ 002).
@Repository
public class ClienteRepository {

    // Convierte cada fila en un Cliente (cod_cliente -> codCliente, etc.)
    private final RowMapper<Cliente> mapper = new DataClassRowMapper<>(Cliente.class);
    private final ConexionBD conexionBD;

    public ClienteRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    public List<Cliente> consultar(Integer codCliente) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_clientes_consultar ?", mapper, codCliente));
    }

    public Cliente insertar(ClienteDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_clientes_insertar ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?", mapper,
                d.nomCliente(), d.codTipoIdentificacion(), d.numIdentificacion(), d.desProvincia(),
                d.desCanton(), d.desDistrito(), d.desBarrio(), d.desProfesion(), d.desActividadEconomica(),
                d.desCorreo(), d.numTelefono(), d.codEstado()));
    }

    public Cliente actualizar(Integer codCliente, ClienteDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_clientes_actualizar ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?", mapper,
                codCliente, d.nomCliente(), d.codTipoIdentificacion(), d.numIdentificacion(), d.desProvincia(),
                d.desCanton(), d.desDistrito(), d.desBarrio(), d.desProfesion(), d.desActividadEconomica(),
                d.desCorreo(), d.numTelefono(), d.codEstado()));
    }

    public void eliminar(Integer codCliente) {
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC facturacion.pa_clientes_eliminar ?", codCliente));
    }
}
