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

    // Errores lanzados por los SP con THROW 5000x: se devuelve el mensaje del SP.
    // 50002 = registro no existe; los demás son reglas de negocio.
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<ErrorResponseDTO> handleDatabase(DataAccessException exception) {
        Throwable causa = NestedExceptionUtils.getMostSpecificCause(exception);
        if (causa instanceof SQLException sql && sql.getErrorCode() >= 50000) {
            HttpStatus status = sql.getErrorCode() == 50002 ? HttpStatus.NOT_FOUND : HttpStatus.BAD_REQUEST;
            return response(status, sql.getMessage());
        }
        return response(HttpStatus.INTERNAL_SERVER_ERROR, "Error en la base de datos: " + causa.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponseDTO> handleGeneric(Exception exception) {
        return response(HttpStatus.INTERNAL_SERVER_ERROR, "Ocurrió un error inesperado.");
    }

    private ResponseEntity<ErrorResponseDTO> response(HttpStatus status, String detail) {
        return ResponseEntity.status(status).body(new ErrorResponseDTO(status.value(), detail));
    }
}
