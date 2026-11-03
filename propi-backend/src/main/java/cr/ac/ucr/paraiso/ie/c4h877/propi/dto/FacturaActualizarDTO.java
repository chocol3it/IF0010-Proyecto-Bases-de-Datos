package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// Datos de una factura que se pueden modificar (no afectan montos)
public record FacturaActualizarDTO(
        @NotNull(message = "La condición de venta es obligatoria") Integer codCondicionVenta,
        @NotNull(message = "El medio de pago es obligatorio") Integer codMedioPago,
        @Size(max = 500) String desObservaciones) {
}
