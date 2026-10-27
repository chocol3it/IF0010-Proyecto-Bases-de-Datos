package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(schema = "facturacion", name = "estados")
public class Estado {

    @Id
    @Column(name = "cod_estado")
    private String codEstado;

    @Column(name = "des_estado")
    private String desEstado;

    public String getCodEstado() {
        return codEstado;
    }

    public String getDesEstado() {
        return desEstado;
    }
}
