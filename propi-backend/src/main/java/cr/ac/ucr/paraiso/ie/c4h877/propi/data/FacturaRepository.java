package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Factura;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.FacturaDetalle;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaActualizarDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaDTO;
import java.util.List;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import tools.jackson.databind.ObjectMapper;

@Repository
public class FacturaRepository {

    private final RowMapper<Factura> mapper = new DataClassRowMapper<>(Factura.class);
    private final RowMapper<FacturaDetalle> mapperDetalle = new DataClassRowMapper<>(FacturaDetalle.class);
    private final ConexionBD conexionBD;
    private final ObjectMapper objectMapper;

    public FacturaRepository(ConexionBD conexionBD, ObjectMapper objectMapper) {
        this.conexionBD = conexionBD;
        this.objectMapper = objectMapper;
    }

    public List<Factura> consultar(Integer codFactura) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_facturas_consultar ?", mapper, codFactura));
    }

    public List<FacturaDetalle> consultarDetalle(Integer codFactura) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_facturas_detalle_consultar ?", mapperDetalle, codFactura));
    }

    // Las líneas viajan al SP como JSON: [{"codProducto":1,"canCantidad":2}, ...]
    public Factura insertar(FacturaDTO d) {
        String detalle = objectMapper.writeValueAsString(d.lineas());
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_facturas_insertar ?, ?, ?, ?, ?, ?, ?", mapper,
                d.codCliente(), d.codCondicionVenta(), d.codMedioPago(), d.codMoneda(), d.monTipoCambio(),
                d.desObservaciones(), detalle));
    }

    public Factura actualizar(Integer codFactura, FacturaActualizarDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_facturas_actualizar ?, ?, ?, ?", mapper,
                codFactura, d.codCondicionVenta(), d.codMedioPago(), d.desObservaciones()));
    }

    public void eliminar(Integer codFactura) {
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC facturacion.pa_facturas_eliminar ?", codFactura));
    }
}
