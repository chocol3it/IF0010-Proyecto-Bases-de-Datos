package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Estado;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoIdentificacion;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;

public interface CatalogoRepository extends Repository<Estado, String> {

    @Query(value = "EXEC facturacion.pa_estados_listar", nativeQuery = true)
    List<Estado> listarEstados();

    @Query(value = "EXEC facturacion.pa_tipos_identificacion_listar", nativeQuery = true)
    List<TipoIdentificacion> listarTiposIdentificacion();
}
