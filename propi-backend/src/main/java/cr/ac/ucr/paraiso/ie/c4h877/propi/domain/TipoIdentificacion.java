package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(schema = "facturacion", name = "tipos_identificacion")
public class TipoIdentificacion {

    @Id
    @Column(name = "cod_tipo_identificacion")
    private Integer codTipoIdentificacion;

    @Column(name = "des_tipo_identificacion")
    private String desTipoIdentificacion;

    public Integer getCodTipoIdentificacion() {
        return codTipoIdentificacion;
    }

    public String getDesTipoIdentificacion() {
        return desTipoIdentificacion;
    }
}
