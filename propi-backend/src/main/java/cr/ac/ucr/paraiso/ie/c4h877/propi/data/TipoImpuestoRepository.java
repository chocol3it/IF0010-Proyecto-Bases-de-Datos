package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoImpuesto;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.TipoImpuestoDTO;
import java.util.List;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class TipoImpuestoRepository {

    private final RowMapper<TipoImpuesto> mapper = new DataClassRowMapper<>(TipoImpuesto.class);
    private final ConexionBD conexionBD;

    public TipoImpuestoRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    public List<TipoImpuesto> consultar(Integer codTipoImpuesto) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_tipos_impuesto_consultar ?", mapper, codTipoImpuesto));
    }

    public TipoImpuesto insertar(TipoImpuestoDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_tipos_impuesto_insertar ?, ?, ?, ?", mapper,
                d.codTarifa(), d.desTipoImpuesto(), d.porImpuesto(), d.codEstado()));
    }

    public TipoImpuesto actualizar(Integer codTipoImpuesto, TipoImpuestoDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_tipos_impuesto_actualizar ?, ?, ?, ?, ?", mapper,
                codTipoImpuesto, d.codTarifa(), d.desTipoImpuesto(), d.porImpuesto(), d.codEstado()));
    }

    public void eliminar(Integer codTipoImpuesto) {
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC facturacion.pa_tipos_impuesto_eliminar ?", codTipoImpuesto));
    }
}
