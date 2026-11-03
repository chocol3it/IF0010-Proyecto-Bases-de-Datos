package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.TipoImpuestoRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoImpuesto;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.TipoImpuestoDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class TipoImpuestoService {

    private final TipoImpuestoRepository tipoImpuestoRepository;

    public TipoImpuestoService(TipoImpuestoRepository tipoImpuestoRepository) {
        this.tipoImpuestoRepository = tipoImpuestoRepository;
    }

    public List<TipoImpuesto> listar() {
        return tipoImpuestoRepository.consultar(null);
    }

    public TipoImpuesto obtener(Integer codTipoImpuesto) {
        return tipoImpuestoRepository.consultar(codTipoImpuesto).stream().findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Tipo de impuesto " + codTipoImpuesto + " no encontrado"));
    }

    public TipoImpuesto crear(TipoImpuestoDTO tipoImpuesto) {
        return tipoImpuestoRepository.insertar(tipoImpuesto);
    }

    public TipoImpuesto actualizar(Integer codTipoImpuesto, TipoImpuestoDTO tipoImpuesto) {
        return tipoImpuestoRepository.actualizar(codTipoImpuesto, tipoImpuesto);
    }

    public void eliminar(Integer codTipoImpuesto) {
        tipoImpuestoRepository.eliminar(codTipoImpuesto);
    }
}
