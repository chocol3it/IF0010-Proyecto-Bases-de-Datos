package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.NotaRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Nota;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.NotaDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class NotaService {

    private final NotaRepository notaRepository;

    public NotaService(NotaRepository notaRepository) {
        this.notaRepository = notaRepository;
    }

    public List<Nota> listar(Integer codFactura) {
        return notaRepository.consultar(null, codFactura);
    }

    public Nota obtener(Integer codNota) {
        return notaRepository.consultar(codNota, null).stream().findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Nota " + codNota + " no encontrada"));
    }

    public Nota crear(NotaDTO nota) {
        return notaRepository.insertar(nota);
    }

    public Nota actualizar(Integer codNota, NotaDTO nota) {
        return notaRepository.actualizar(codNota, nota);
    }

    public void eliminar(Integer codNota) {
        notaRepository.eliminar(codNota);
    }
}
