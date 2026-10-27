package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// Datos que envía el frontend para crear o modificar un cliente.
public record ClienteDTO(
        @NotBlank(message = "El nombre es obligatorio") @Size(max = 150) String nomCliente,
        @NotNull(message = "El tipo de identificación es obligatorio") Integer codTipoIdentificacion,
        @NotBlank(message = "La identificación es obligatoria") @Size(max = 20) String numIdentificacion,
        @NotBlank(message = "La provincia es obligatoria") @Size(max = 50) String desProvincia,
        @NotBlank(message = "El cantón es obligatorio") @Size(max = 50) String desCanton,
        @NotBlank(message = "El distrito es obligatorio") @Size(max = 50) String desDistrito,
        @Size(max = 100) String desBarrio,
        @Size(max = 100) String desProfesion,
        @Size(max = 150) String desActividadEconomica,
        @NotBlank(message = "El correo es obligatorio") @Email(message = "Correo inválido") @Size(max = 150) String desCorreo,
        @NotBlank(message = "El teléfono es obligatorio") @Size(max = 20) String numTelefono,
        @NotBlank(message = "El estado es obligatorio") @Pattern(regexp = "[AI]", message = "Estado inválido") String codEstado) {
}
