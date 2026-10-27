package cr.ac.ucr.paraiso.ie.c4h877.propi.data;

import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Cliente;
import java.util.List;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

// Se extiende Repository (y no JpaRepository) para que no existan métodos
// como save() o findAll() que irían directo a la tabla: todo pasa por los SP.
public interface ClienteRepository extends Repository<Cliente, Integer> {

    @Query(value = "EXEC facturacion.pa_clientes_consultar", nativeQuery = true)
    List<Cliente> consultarTodos();

    @Query(value = "EXEC facturacion.pa_clientes_consultar :codCliente", nativeQuery = true)
    Cliente consultarPorId(@Param("codCliente") Integer codCliente);

    @Query(value = """
            EXEC facturacion.pa_clientes_insertar
                :nomCliente, :codTipoIdentificacion, :numIdentificacion, :desProvincia, :desCanton,
                :desDistrito, :desBarrio, :desProfesion, :desActividadEconomica, :desCorreo,
                :numTelefono, :codEstado
            """, nativeQuery = true)
    Cliente insertar(@Param("nomCliente") String nomCliente,
            @Param("codTipoIdentificacion") Integer codTipoIdentificacion,
            @Param("numIdentificacion") String numIdentificacion,
            @Param("desProvincia") String desProvincia,
            @Param("desCanton") String desCanton,
            @Param("desDistrito") String desDistrito,
            @Param("desBarrio") String desBarrio,
            @Param("desProfesion") String desProfesion,
            @Param("desActividadEconomica") String desActividadEconomica,
            @Param("desCorreo") String desCorreo,
            @Param("numTelefono") String numTelefono,
            @Param("codEstado") String codEstado);

    @Query(value = """
            EXEC facturacion.pa_clientes_actualizar
                :codCliente, :nomCliente, :codTipoIdentificacion, :numIdentificacion, :desProvincia,
                :desCanton, :desDistrito, :desBarrio, :desProfesion, :desActividadEconomica,
                :desCorreo, :numTelefono, :codEstado
            """, nativeQuery = true)
    Cliente actualizar(@Param("codCliente") Integer codCliente,
            @Param("nomCliente") String nomCliente,
            @Param("codTipoIdentificacion") Integer codTipoIdentificacion,
            @Param("numIdentificacion") String numIdentificacion,
            @Param("desProvincia") String desProvincia,
            @Param("desCanton") String desCanton,
            @Param("desDistrito") String desDistrito,
            @Param("desBarrio") String desBarrio,
            @Param("desProfesion") String desProfesion,
            @Param("desActividadEconomica") String desActividadEconomica,
            @Param("desCorreo") String desCorreo,
            @Param("numTelefono") String numTelefono,
            @Param("codEstado") String codEstado);

    @Modifying
    @Query(value = "EXEC facturacion.pa_clientes_eliminar :codCliente", nativeQuery = true)
    void eliminar(@Param("codCliente") Integer codCliente);
}
