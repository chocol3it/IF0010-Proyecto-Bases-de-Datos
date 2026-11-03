package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Repository;

// REQ 007: cada reporte es un procedimiento almacenado. Las filas se devuelven tal
// cual las entrega SQL Server (nombre de columna -> valor).
@Repository
public class ReporteRepository {

    private final ConexionBD conexionBD;

    public ReporteRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    public List<Map<String, Object>> clientes(LocalDate desde, LocalDate hasta, String estado) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForList(
                "EXEC facturacion.pa_rpt_clientes ?, ?, ?", desde, hasta, estado));
    }

    public List<Map<String, Object>> facturas(LocalDate desde, LocalDate hasta) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForList(
                "EXEC facturacion.pa_rpt_facturas ?, ?", desde, hasta));
    }

    public List<Map<String, Object>> auditoria(LocalDate desde, LocalDate hasta, String usuario) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForList(
                "EXEC facturacion.pa_rpt_auditoria ?, ?, ?", desde, hasta, usuario));
    }

    public List<Map<String, Object>> seguridad(String usuario) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForList(
                "EXEC facturacion.pa_rpt_seguridad ?", usuario));
    }
}
