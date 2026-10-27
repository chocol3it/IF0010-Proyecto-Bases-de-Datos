package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.ClienteRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Cliente;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ClienteDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// Las transacciones de negocio viven en los procedimientos almacenados
// (BEGIN/COMMIT/ROLLBACK); aquí solo se llaman.
@Service
public class ClienteService {

    private final ClienteRepository clienteRepository;

    public ClienteService(ClienteRepository clienteRepository) {
        this.clienteRepository = clienteRepository;
    }

    public List<Cliente> listar() {
        return clienteRepository.consultarTodos();
    }

    public Cliente obtener(Integer codCliente) {
        Cliente cliente = clienteRepository.consultarPorId(codCliente);
        if (cliente == null) {
            throw new ResourceNotFoundException("Cliente con código " + codCliente + " no encontrado");
        }
        return cliente;
    }

    public Cliente crear(ClienteDTO d) {
        return clienteRepository.insertar(d.nomCliente(), d.codTipoIdentificacion(), d.numIdentificacion(),
                d.desProvincia(), d.desCanton(), d.desDistrito(), d.desBarrio(), d.desProfesion(),
                d.desActividadEconomica(), d.desCorreo(), d.numTelefono(), d.codEstado());
    }

    public Cliente actualizar(Integer codCliente, ClienteDTO d) {
        return clienteRepository.actualizar(codCliente, d.nomCliente(), d.codTipoIdentificacion(),
                d.numIdentificacion(), d.desProvincia(), d.desCanton(), d.desDistrito(), d.desBarrio(),
                d.desProfesion(), d.desActividadEconomica(), d.desCorreo(), d.numTelefono(), d.codEstado());
    }

    // JPA exige una transacción para las consultas @Modifying
    @Transactional
    public void eliminar(Integer codCliente) {
        clienteRepository.eliminar(codCliente);
    }
}
