package cr.ac.ucr.paraiso.ie.c4h877.propi.controller;

import cr.ac.ucr.paraiso.ie.c4h877.propi.business.AuthService;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.LoginRespuestaDTO;
import jakarta.servlet.http.HttpServletRequest;
import java.net.InetAddress;
import java.net.UnknownHostException;
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
    public ResponseEntity<LoginRespuestaDTO> login(@Valid @RequestBody LoginDTO datos, HttpServletRequest request)
            throws UnknownHostException {
        String terminal = request.getRemoteHost();
        // Si la petición viene del mismo equipo, se guarda su nombre en lugar de la IP local (::1 o 127.0.0.1)
        if (InetAddress.getByName(request.getRemoteAddr()).isLoopbackAddress()) {
            terminal = InetAddress.getLocalHost().getHostName();
        }
        return ResponseEntity.ok(authService.login(datos, terminal, request.getRemoteAddr()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        authService.logout();
        return ResponseEntity.noContent().build();
    }
}
