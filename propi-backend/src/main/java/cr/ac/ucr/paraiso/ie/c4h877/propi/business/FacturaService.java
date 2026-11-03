package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.FacturaRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Factura;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.FacturaDetalle;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaActualizarDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class FacturaService {

    private final FacturaRepository facturaRepository;

    public FacturaService(FacturaRepository facturaRepository) {
        this.facturaRepository = facturaRepository;
    }

    public List<Factura> listar() {
        return facturaRepository.consultar(null);
    }

    public Factura obtener(Integer codFactura) {
        return facturaRepository.consultar(codFactura).stream().findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Factura " + codFactura + " no encontrada"));
    }

    public List<FacturaDetalle> detalle(Integer codFactura) {
        return facturaRepository.consultarDetalle(codFactura);
    }

    public Factura crear(FacturaDTO factura) {
        return facturaRepository.insertar(factura);
    }

    public Factura actualizar(Integer codFactura, FacturaActualizarDTO factura) {
        return facturaRepository.actualizar(codFactura, factura);
    }

    public void eliminar(Integer codFactura) {
        facturaRepository.eliminar(codFactura);
    }
}
