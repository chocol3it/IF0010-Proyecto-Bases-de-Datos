package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.CatalogoService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Catalogo;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/catalogos")
public class CatalogoController {

    private final CatalogoService catalogoService;

    public CatalogoController(CatalogoService catalogoService) {
        this.catalogoService = catalogoService;
    }

    // Ej.: /api/v1/catalogos/medios-pago
    @GetMapping("/{nombre}")
    public ResponseEntity<List<Catalogo>> listar(@PathVariable String nombre) {
        return ResponseEntity.ok(catalogoService.listar(nombre));
    }
}
