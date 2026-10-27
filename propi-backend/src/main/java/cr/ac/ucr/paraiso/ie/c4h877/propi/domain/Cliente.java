package cr.ac.ucr.paraiso.ie.c4h877.propi.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;

// Solo mapea el resultado de los procedimientos almacenados; los cambios
// a la tabla se hacen siempre por medio de los SP (ver ClienteRepository).
@Entity
@Table(schema = "facturacion", name = "clientes")
public class Cliente {

    @Id
    @Column(name = "cod_cliente")
    private Integer codCliente;

    @Column(name = "nom_cliente")
    private String nomCliente;

    @Column(name = "cod_tipo_identificacion")
    private Integer codTipoIdentificacion;

    @Column(name = "num_identificacion")
    private String numIdentificacion;

    @Column(name = "des_provincia")
    private String desProvincia;

    @Column(name = "des_canton")
    private String desCanton;

    @Column(name = "des_distrito")
    private String desDistrito;

    @Column(name = "des_barrio")
    private String desBarrio;

    @Column(name = "des_profesion")
    private String desProfesion;

    @Column(name = "des_actividad_economica")
    private String desActividadEconomica;

    @Column(name = "des_correo")
    private String desCorreo;

    @Column(name = "num_telefono")
    private String numTelefono;

    @Column(name = "fec_registro")
    private LocalDateTime fecRegistro;

    @Column(name = "cod_estado")
    private String codEstado;

    public Cliente() {
    }

    public Integer getCodCliente() {
        return codCliente;
    }

    public void setCodCliente(Integer codCliente) {
        this.codCliente = codCliente;
    }

    public String getNomCliente() {
        return nomCliente;
    }

    public void setNomCliente(String nomCliente) {
        this.nomCliente = nomCliente;
    }

    public Integer getCodTipoIdentificacion() {
        return codTipoIdentificacion;
    }

    public void setCodTipoIdentificacion(Integer codTipoIdentificacion) {
        this.codTipoIdentificacion = codTipoIdentificacion;
    }

    public String getNumIdentificacion() {
        return numIdentificacion;
    }

    public void setNumIdentificacion(String numIdentificacion) {
        this.numIdentificacion = numIdentificacion;
    }

    public String getDesProvincia() {
        return desProvincia;
    }

    public void setDesProvincia(String desProvincia) {
        this.desProvincia = desProvincia;
    }

    public String getDesCanton() {
        return desCanton;
    }

    public void setDesCanton(String desCanton) {
        this.desCanton = desCanton;
    }

    public String getDesDistrito() {
        return desDistrito;
    }

    public void setDesDistrito(String desDistrito) {
        this.desDistrito = desDistrito;
    }

    public String getDesBarrio() {
        return desBarrio;
    }

    public void setDesBarrio(String desBarrio) {
        this.desBarrio = desBarrio;
    }

    public String getDesProfesion() {
        return desProfesion;
    }

    public void setDesProfesion(String desProfesion) {
        this.desProfesion = desProfesion;
    }

    public String getDesActividadEconomica() {
        return desActividadEconomica;
    }

    public void setDesActividadEconomica(String desActividadEconomica) {
        this.desActividadEconomica = desActividadEconomica;
    }

    public String getDesCorreo() {
        return desCorreo;
    }

    public void setDesCorreo(String desCorreo) {
        this.desCorreo = desCorreo;
    }

    public String getNumTelefono() {
        return numTelefono;
    }

    public void setNumTelefono(String numTelefono) {
        this.numTelefono = numTelefono;
    }

    public LocalDateTime getFecRegistro() {
        return fecRegistro;
    }

    public void setFecRegistro(LocalDateTime fecRegistro) {
        this.fecRegistro = fecRegistro;
    }

    public String getCodEstado() {
        return codEstado;
    }

    public void setCodEstado(String codEstado) {
        this.codEstado = codEstado;
    }
}
