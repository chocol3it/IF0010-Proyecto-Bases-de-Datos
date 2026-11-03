package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

// Una línea de factura: el SP calcula precio, impuesto y montos
public record LineaDTO(
        @NotNull(message = "El producto es obligatorio") Integer codProducto,
        @NotNull(message = "La cantidad es obligatoria") @DecimalMin(value = "0.01", message = "La cantidad debe ser mayor a cero") BigDecimal canCantidad) {
}
