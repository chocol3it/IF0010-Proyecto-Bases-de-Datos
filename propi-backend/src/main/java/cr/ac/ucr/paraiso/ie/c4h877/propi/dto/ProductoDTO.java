package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record ProductoDTO(
        @NotBlank(message = "El código CABYS es obligatorio") @Pattern(regexp = "\\d{13}", message = "El CABYS tiene 13 dígitos") String codCabys,
        @NotBlank(message = "La descripción es obligatoria") @Size(max = 200) String desProducto,
        @NotNull(message = "La unidad de medida es obligatoria") Integer codUnidadMedida,
        @NotNull(message = "El precio es obligatorio") @DecimalMin("0") BigDecimal monPrecio,
        @NotNull(message = "El tipo de impuesto es obligatorio") Integer codTipoImpuesto,
        @NotBlank @Pattern(regexp = "[AI]", message = "Estado inválido") String codEstado) {
}
