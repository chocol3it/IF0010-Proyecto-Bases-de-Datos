package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.CatalogoService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Estado;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.TipoIdentificacion;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/catalogos")
public class CatalogoController {

    private final CatalogoService catalogoService;

    public CatalogoController(CatalogoService catalogoService) {
        this.catalogoService = catalogoService;
    }

    @GetMapping("/estados")
    public ResponseEntity<List<Estado>> estados() {
        return ResponseEntity.ok(catalogoService.listarEstados());
    }

    @GetMapping("/tipos-identificacion")
    public ResponseEntity<List<TipoIdentificacion>> tiposIdentificacion() {
        return ResponseEntity.ok(catalogoService.listarTiposIdentificacion());
    }
}
