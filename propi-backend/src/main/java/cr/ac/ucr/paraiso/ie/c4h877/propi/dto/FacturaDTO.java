package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;

public record FacturaDTO(
        @NotNull(message = "El cliente es obligatorio") Integer codCliente,
        @NotNull(message = "La condición de venta es obligatoria") Integer codCondicionVenta,
        @NotNull(message = "El medio de pago es obligatorio") Integer codMedioPago,
        @NotNull(message = "La moneda es obligatoria") Integer codMoneda,
        @NotNull(message = "El tipo de cambio es obligatorio") @DecimalMin(value = "0.0001") BigDecimal monTipoCambio,
        @Size(max = 500) String desObservaciones,
        @NotEmpty(message = "La factura debe tener al menos una línea") @Valid List<LineaDTO> lineas) {
}
