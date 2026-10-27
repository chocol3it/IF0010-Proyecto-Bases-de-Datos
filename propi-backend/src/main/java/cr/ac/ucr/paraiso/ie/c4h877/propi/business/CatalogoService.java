package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.CatalogoRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Estado;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoIdentificacion;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class CatalogoService {

    private final CatalogoRepository catalogoRepository;

    public CatalogoService(CatalogoRepository catalogoRepository) {
        this.catalogoRepository = catalogoRepository;
    }

    public List<Estado> listarEstados() {
        return catalogoRepository.listarEstados();
    }

    public List<TipoIdentificacion> listarTiposIdentificacion() {
        return catalogoRepository.listarTiposIdentificacion();
    }
}
