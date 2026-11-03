package cr.ac.ucr.paraiso.ie.c4h877.propi.security;

// Datos del usuario que viajan dentro del JWT.
// codSesion es el cod_acceso de auditoria.bitacora_acceso.
public record UsuarioSesion(String usuario, String rol, Integer codSesion) {
}
