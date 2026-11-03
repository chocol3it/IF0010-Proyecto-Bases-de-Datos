package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.FacturaService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Factura;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.FacturaDetalle;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaActualizarDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.FacturaDTO;
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
@RequestMapping("/api/v1/facturas")
public class FacturaController {

    private final FacturaService facturaService;

    public FacturaController(FacturaService facturaService) {
        this.facturaService = facturaService;
    }

    @GetMapping
    public ResponseEntity<List<Factura>> listar() {
        return ResponseEntity.ok(facturaService.listar());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Factura> obtener(@PathVariable Integer id) {
        return ResponseEntity.ok(facturaService.obtener(id));
    }

    @GetMapping("/{id}/detalle")
    public ResponseEntity<List<FacturaDetalle>> detalle(@PathVariable Integer id) {
        return ResponseEntity.ok(facturaService.detalle(id));
    }

    @PostMapping
    public ResponseEntity<Factura> crear(@Valid @RequestBody FacturaDTO factura) {
        return ResponseEntity.status(HttpStatus.CREATED).body(facturaService.crear(factura));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Factura> actualizar(@PathVariable Integer id, @Valid @RequestBody FacturaActualizarDTO factura) {
        return ResponseEntity.ok(facturaService.actualizar(id, factura));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Integer id) {
        facturaService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
