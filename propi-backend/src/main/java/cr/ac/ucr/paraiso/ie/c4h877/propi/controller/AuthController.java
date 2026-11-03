package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.AuthService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginRespuestaDTO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    // La terminal y la IP son las del equipo que hace la petición (bitácora de accesos)
    @PostMapping("/login")
    public ResponseEntity<LoginRespuestaDTO> login(@Valid @RequestBody LoginDTO datos, HttpServletRequest request) {
        return ResponseEntity.ok(authService.login(datos, request.getRemoteHost(), request.getRemoteAddr()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        authService.logout();
        return ResponseEntity.noContent().build();
    }
}
