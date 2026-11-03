package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.math.BigDecimal;

public record Producto(Integer codProducto, String codCabys, String desProducto, Integer codUnidadMedida,
        String desUnidadMedida, BigDecimal monPrecio, Integer codTipoImpuesto, String desTipoImpuesto,
        BigDecimal porImpuesto, String codEstado) {
}
