package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record TipoImpuestoDTO(
        @NotBlank(message = "La tarifa es obligatoria") @Pattern(regexp = "\\d{2}", message = "La tarifa son 2 dígitos, ej. 08") String codTarifa,
        @NotBlank(message = "La descripción es obligatoria") @Size(max = 100) String desTipoImpuesto,
        @NotNull(message = "El porcentaje es obligatorio") @DecimalMin("0") @DecimalMax("100") BigDecimal porImpuesto,
        @NotBlank @Pattern(regexp = "[AI]", message = "Estado inválido") String codEstado) {
}
