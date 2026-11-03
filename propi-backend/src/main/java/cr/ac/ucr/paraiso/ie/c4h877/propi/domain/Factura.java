package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record Factura(Integer codFactura, Integer codCliente, String nomCliente, LocalDateTime fecFactura,
        Integer codCondicionVenta, String desCondicionVenta, Integer codMedioPago, String desMedioPago,
        Integer codMoneda, String codIso, BigDecimal monTipoCambio, String desObservaciones,
        BigDecimal monSubtotal, BigDecimal monTotalImpuestos, BigDecimal monTotal) {
}
