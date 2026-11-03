package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.TipoImpuestoService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoImpuesto;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.TipoImpuestoDTO;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/tipos-impuesto")
public class TipoImpuestoController {

    private final TipoImpuestoService tipoImpuestoService;

    public TipoImpuestoController(TipoImpuestoService tipoImpuestoService) {
        this.tipoImpuestoService = tipoImpuestoService;
    }

    @GetMapping
    public ResponseEntity<List<TipoImpuesto>> listar() {
        return ResponseEntity.ok(tipoImpuestoService.listar());
    }

    @GetMapping("/{id}")
    public ResponseEntity<TipoImpuesto> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(tipoImpuestoService.obtener(id));
    }

    @PostMapping
    public ResponseEntity<TipoImpuesto> crear(@Valid @RequestBody TipoImpuestoDTO tipoImpuesto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(tipoImpuestoService.crear(tipoImpuesto));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TipoImpuesto> actualizar(@PathVariable Integer id, @Valid @RequestBody TipoImpuestoDTO tipoImpuesto) {
        return ResponseEntity.ok(tipoImpuestoService.actualizar(id, tipoImpuesto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Integer id) {
        tipoImpuestoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
