package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.math.BigDecimal;

public record FacturaDetalle(Integer codDetalle, Integer codFactura, Integer codProducto, String codCabys,
        String desProducto, BigDecimal canCantidad, BigDecimal monPrecioUnitario, BigDecimal monImpuesto,
        BigDecimal monLinea) {
}
