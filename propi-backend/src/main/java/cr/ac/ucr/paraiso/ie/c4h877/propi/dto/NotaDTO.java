package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record NotaDTO(
        @NotNull(message = "La factura es obligatoria") Integer codFactura,
        @NotNull(message = "El tipo de nota es obligatorio") Integer codTipoNota,
        @NotBlank(message = "El motivo es obligatorio") @Size(max = 300) String desMotivo,
        @NotNull(message = "El monto es obligatorio") @DecimalMin(value = "0.01", message = "El monto debe ser mayor a cero") BigDecimal monNota) {
}
