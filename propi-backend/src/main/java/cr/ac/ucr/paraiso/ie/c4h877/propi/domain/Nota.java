package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record Nota(Integer codNota, LocalDateTime fecNota, Integer codFactura, Integer codTipoNota,
        String desTipoNota, String desMotivo, BigDecimal monNota) {
}
