package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.NotaService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Nota;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.NotaDTO;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notas")
public class NotaController {

    private final NotaService notaService;

    public NotaController(NotaService notaService) {
        this.notaService = notaService;
    }

    // ?factura=5 para ver solo las notas de una factura
    @GetMapping
    public ResponseEntity<List<Nota>> listar(@RequestParam(required = false) Integer factura) {
        return ResponseEntity.ok(notaService.listar(factura));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Nota> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(notaService.obtener(id));
    }

    @PostMapping
    public ResponseEntity<Nota> crear(@Valid @RequestBody NotaDTO nota) {
        return ResponseEntity.status(HttpStatus.CREATED).body(notaService.crear(nota));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Nota> actualizar(@PathVariable Integer id, @Valid @RequestBody NotaDTO nota) {
        return ResponseEntity.ok(notaService.actualizar(id, nota));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Integer id) {
        notaService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
