package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.CatalogoRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Catalogo;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class CatalogoService {

    // Solo estos catálogos se pueden consultar (nombre en la URL -> procedimiento)
    private static final Map<String, String> PROCEDIMIENTOS = Map.of(
            "estados", "pa_estados_listar",
            "tipos-identificacion", "pa_tipos_identificacion_listar",
            "condiciones-venta", "pa_condiciones_venta_listar",
            "medios-pago", "pa_medios_pago_listar",
            "monedas", "pa_monedas_listar",
            "unidades-medida", "pa_unidades_medida_listar",
            "tipos-nota", "pa_tipos_nota_listar");

    private final CatalogoRepository catalogoRepository;

    public CatalogoService(CatalogoRepository catalogoRepository) {
        this.catalogoRepository = catalogoRepository;
    }

    public List<Catalogo> listar(String nombre) {
        String procedimiento = PROCEDIMIENTOS.get(nombre);
        if (procedimiento == null) {
            throw new ResourceNotFoundException("El catálogo " + nombre + " no existe");
        }
        return catalogoRepository.listar(procedimiento);
    }
}
