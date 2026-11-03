package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.time.LocalDateTime;

// Fila que devuelve facturacion.pa_clientes_consultar (los datos sensibles ya vienen descifrados).
// Los nombres siguen las columnas: cod_cliente -> codCliente, etc.
public record Cliente(Integer codCliente, String nomCliente, Integer codTipoIdentificacion,
        String desTipoIdentificacion, String numIdentificacion, String desProvincia, String desCanton,
        String desDistrito, String desBarrio, String desProfesion, String desActividadEconomica,
        String desCorreo, String numTelefono, LocalDateTime fecRegistro, String codEstado) {
}
