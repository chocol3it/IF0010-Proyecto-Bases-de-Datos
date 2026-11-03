package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Producto;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ProductoDTO;
import java.util.List;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class ProductoRepository {

    private final RowMapper<Producto> mapper = new DataClassRowMapper<>(Producto.class);
    private final ConexionBD conexionBD;

    public ProductoRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    public List<Producto> consultar(Integer codProducto) {
        return conexionBD.ejecutar(jdbc -> jdbc.query(
                "EXEC facturacion.pa_productos_consultar ?", mapper, codProducto));
    }

    public Producto insertar(ProductoDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_productos_insertar ?, ?, ?, ?, ?, ?", mapper,
                d.codCabys(), d.desProducto(), d.codUnidadMedida(), d.monPrecio(), d.codTipoImpuesto(),
                d.codEstado()));
    }

    public Producto actualizar(Integer codProducto, ProductoDTO d) {
        return conexionBD.ejecutar(jdbc -> jdbc.queryForObject(
                "EXEC facturacion.pa_productos_actualizar ?, ?, ?, ?, ?, ?, ?", mapper,
                codProducto, d.codCabys(), d.desProducto(), d.codUnidadMedida(), d.monPrecio(),
                d.codTipoImpuesto(), d.codEstado()));
    }

    public void eliminar(Integer codProducto) {
        conexionBD.ejecutar(jdbc -> jdbc.update("EXEC facturacion.pa_productos_eliminar ?", codProducto));
    }
}
