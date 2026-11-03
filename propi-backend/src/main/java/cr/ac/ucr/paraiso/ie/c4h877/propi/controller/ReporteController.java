package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.ReporteService;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// Las fechas llegan como yyyy-MM-dd, ej. /api/v1/reportes/facturas?desde=2026-11-01&hasta=2026-11-30
@RestController
@RequestMapping("/api/v1/reportes")
public class ReporteController {

    private final ReporteService reporteService;

    public ReporteController(ReporteService reporteService) {
        this.reporteService = reporteService;
    }

    @GetMapping("/clientes")
    public ResponseEntity<List<Map<String, Object>>> clientes(@RequestParam LocalDate desde,
            @RequestParam LocalDate hasta, @RequestParam(required = false) String estado) {
        return ResponseEntity.ok(reporteService.clientes(desde, hasta, estado));
    }

    @GetMapping("/facturas")
    public ResponseEntity<List<Map<String, Object>>> facturas(@RequestParam LocalDate desde,
            @RequestParam LocalDate hasta) {
        return ResponseEntity.ok(reporteService.facturas(desde, hasta));
    }

    @GetMapping("/auditoria")
    public ResponseEntity<List<Map<String, Object>>> auditoria(@RequestParam LocalDate desde,
            @RequestParam LocalDate hasta, @RequestParam(required = false) String usuario) {
        return ResponseEntity.ok(reporteService.auditoria(desde, hasta, usuario));
    }

    @GetMapping("/seguridad")
    public ResponseEntity<List<Map<String, Object>>> seguridad(@RequestParam(required = false) String usuario) {
        return ResponseEntity.ok(reporteService.seguridad(usuario));
    }
}
