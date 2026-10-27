package cr.ac.ucr.paraiso.ie.c4h877.propi.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ErrorResponseDTO(int status, String detail, Map<String, String> invalidFields) {

    public ErrorResponseDTO(int status, String detail) {
        this(status, detail, null);
    }
}
