package cr.ac.ucr.paraiso.ie.c4h877.propi.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class JwtTokenProvider {

    private final SecretKey key;
    private final long jwtExpirationInMs;

    public JwtTokenProvider(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.expiration-ms}") long jwtExpirationInMs) {
        if (secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalArgumentException("app.jwt.secret debe tener al menos 32 bytes");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.jwtExpirationInMs = jwtExpirationInMs;
    }

    public String generarToken(UsuarioSesion sesion) {
        Date ahora = new Date();
        return Jwts.builder()
                .subject(sesion.usuario())
                .claim("rol", sesion.rol())
                .claim("sesion", sesion.codSesion())
                .issuedAt(ahora)
                .expiration(new Date(ahora.getTime() + jwtExpirationInMs))
                .signWith(key)
                .compact();
    }

    // Devuelve null si el token es inválido o expiró
    public UsuarioSesion leerToken(String token) {
        try {
            Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            return new UsuarioSesion(claims.getSubject(), claims.get("rol", String.class),
                    claims.get("sesion", Integer.class));
        } catch (JwtException | IllegalArgumentException exception) {
            return null;
        }
    }
}
