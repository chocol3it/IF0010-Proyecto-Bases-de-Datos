package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.math.BigDecimal;

public record TipoImpuesto(Integer codTipoImpuesto, String codTarifa, String desTipoImpuesto,
        BigDecimal porImpuesto, String codEstado) {
}
