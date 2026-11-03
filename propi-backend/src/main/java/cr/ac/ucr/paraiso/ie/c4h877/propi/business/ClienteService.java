package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.ClienteRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Cliente;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ClienteDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;

// Las transacciones y reglas de negocio viven en los procedimientos almacenados
// (BEGIN/COMMIT/ROLLBACK); el servicio solo los llama.
@Service
public class ClienteService {

    private final ClienteRepository clienteRepository;

    public ClienteService(ClienteRepository clienteRepository) {
        this.clienteRepository = clienteRepository;
    }

    public List<Cliente> listar() {
        return clienteRepository.consultar(null);
    }

    public Cliente obtener(Integer codCliente) {
        return clienteRepository.consultar(codCliente).stream().findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Cliente " + codCliente + " no encontrado"));
    }

    public Cliente crear(ClienteDTO cliente) {
        return clienteRepository.insertar(cliente);
    }

    public Cliente actualizar(Integer codCliente, ClienteDTO cliente) {
        return clienteRepository.actualizar(codCliente, cliente);
    }

    public void eliminar(Integer codCliente) {
        clienteRepository.eliminar(codCliente);
    }
}
