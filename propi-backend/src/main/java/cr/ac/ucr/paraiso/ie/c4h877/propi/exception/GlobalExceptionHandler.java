package cr.ac.ucr.paraiso.ie.c4h877.propi.exception;

import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ErrorResponseDTO;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;
import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponseDTO> handleValidation(MethodArgumentNotValidException exception) {
        Map<String, String> errores = new HashMap<>();
        for (FieldError fieldError : exception.getBindingResult().getFieldErrors()) {
            errores.put(fieldError.getField(), fieldError.getDefaultMessage());
        }
        return ResponseEntity.badRequest()
                .body(new ErrorResponseDTO(400, "Los datos enviados no son válidos.", errores));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponseDTO> handleBodyIlegible(HttpMessageNotReadableException exception) {
        return response(HttpStatus.BAD_REQUEST, "El cuerpo de la petición no es un JSON válido.");
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponseDTO> handleNotFound(ResourceNotFoundException exception) {
        return response(HttpStatus.NOT_FOUND, exception.getMessage());
    }

    // Errores que devuelve SQL Server:
    //   229       -> el rol del usuario no tiene permiso sobre el procedimiento (REQ 008)
    //   50002     -> THROW de un SP: registro inexistente
    //   50004     -> THROW de un SP: usuario sin rol
    //   otros 5xxxx -> THROW de un SP: regla de negocio
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<ErrorResponseDTO> handleDatabase(DataAccessException exception) {
        Throwable causa = NestedExceptionUtils.getMostSpecificCause(exception);
        if (causa instanceof SQLException sql) {
            int codigo = sql.getErrorCode();
            if (codigo == 229) {
                return response(HttpStatus.FORBIDDEN, "Su rol no tiene permiso para realizar esta operación.");
            }
            if (codigo == 50002) {
                return response(HttpStatus.NOT_FOUND, sql.getMessage());
            }
            if (codigo == 50004) {
                return response(HttpStatus.FORBIDDEN, sql.getMessage());
            }
            if (codigo >= 50000) {
                return response(HttpStatus.BAD_REQUEST, sql.getMessage());
            }
        }
        return response(HttpStatus.INTERNAL_SERVER_ERROR, "Error en la base de datos: " + causa.getMessage());
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ErrorResponseDTO> handleCredenciales(BadCredentialsException exception) {
        return response(HttpStatus.UNAUTHORIZED, exception.getMessage());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponseDTO> handleIllegalArgument(IllegalArgumentException exception) {
        return response(HttpStatus.BAD_REQUEST, exception.getMessage());
    }

    // Ej.: no se pudo abrir la conexión a SQL Server durante el login
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ErrorResponseDTO> handleIllegalState(IllegalStateException exception) {
        return response(HttpStatus.SERVICE_UNAVAILABLE, exception.getMessage());
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ErrorResponseDTO> handleParametro(MissingServletRequestParameterException exception) {
        return response(HttpStatus.BAD_REQUEST, "Falta el parámetro " + exception.getParameterName() + ".");
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponseDTO> handleGeneric(Exception exception) {
        return response(HttpStatus.INTERNAL_SERVER_ERROR, "Ocurrió un error inesperado.");
    }

    private ResponseEntity<ErrorResponseDTO> response(HttpStatus status, String detail) {
        return ResponseEntity.status(status).body(new ErrorResponseDTO(status.value(), detail));
    }
}
