package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginDTO(
        @NotBlank(message = "El usuario es obligatorio") String usuario,
        @NotBlank(message = "La contraseña es obligatoria") String contrasena) {
}
