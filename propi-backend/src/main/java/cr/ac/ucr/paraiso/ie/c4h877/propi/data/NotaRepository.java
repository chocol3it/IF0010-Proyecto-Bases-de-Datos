package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Nota;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.NotaDTO;
import java.util.List;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class NotaRepository {

    private final RowMapper<Nota> mapper = new DataClassRowMapper<>(Nota.class);
    private final ConexionBD conexionBD;

    public NotaRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    // Una nota (codNota), las de una factura (codFactura) o todas (ambos null)
    public List<Nota> consultar(Integer codNota, Integer codFactura) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_notas_consultar ?, ?", mapper, codNota, codFactura));
    }

    public Nota insertar(NotaDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_notas_insertar ?, ?, ?, ?", mapper,
                d.codFactura(), d.codTipoNota(), d.desMotivo(), d.monNota()));
    }

    public Nota actualizar(Integer codNota, NotaDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_notas_actualizar ?, ?, ?, ?", mapper,
                codNota, d.codTipoNota(), d.desMotivo(), d.monNota()));
    }

    public void eliminar(Integer codNota) {
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC facturacion.pa_notas_eliminar ?", codNota));
    }
}
