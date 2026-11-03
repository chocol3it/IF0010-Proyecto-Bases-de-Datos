package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Catalogo;
import java.util.List;
import org.springframework.stereotype.Repository;

@Repository
public class CatalogoRepository {

    private final ConexionBD conexionBD;

    public CatalogoRepository(ConexionBD conexionBD) {
        this.conexionBD = conexionBD;
    }

    // Todos los pa_*_listar devuelven el código en la columna 1 y la descripción en la 2
    public List<Catalogo> listar(String procedimiento) {
        return conexionBD.ejecutar(jdbc -> jdbc.query("EXEC facturacion." + procedimiento,
                (rs, fila) -> new Catalogo(rs.getObject(1), rs.getString(2))));
    }
}
