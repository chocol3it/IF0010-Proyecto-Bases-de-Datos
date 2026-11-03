package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.ReporteRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class ReporteService {

    private final ReporteRepository reporteRepository;

    public ReporteService(ReporteRepository reporteRepository) {
        this.reporteRepository = reporteRepository;
    }

    public List<Map<String, Object>> clientes(LocalDate desde, LocalDate hasta, String estado) {
        validarFechas(desde, hasta);
        return reporteRepository.clientes(desde, hasta, vacioANull(estado));
    }

    public List<Map<String, Object>> facturas(LocalDate desde, LocalDate hasta) {
        validarFechas(desde, hasta);
        return reporteRepository.facturas(desde, hasta);
    }

    public List<Map<String, Object>> auditoria(LocalDate desde, LocalDate hasta, String usuario) {
        validarFechas(desde, hasta);
        return reporteRepository.auditoria(desde, hasta, vacioANull(usuario));
    }

    public List<Map<String, Object>> seguridad(String usuario) {
        return reporteRepository.seguridad(vacioANull(usuario));
    }

    private void validarFechas(LocalDate desde, LocalDate hasta) {
        if (desde.isAfter(hasta)) {
            throw new IllegalArgumentException("La fecha desde no puede ser mayor que la fecha hasta.");
        }
    }

    // "Todos" llega como texto vacío y el SP lo espera como NULL
    private String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor;
    }
}
