import { Component, inject } from '@angular/core';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-inicio',
  template: `
    <h2>Bienvenido, {{ authService.usuario() }}</h2>
    <p>Rol: <strong>{{ authService.rol() }}</strong></p>
    <p>Use el menú superior para acceder a los módulos de su rol.</p>
  `,
})
export class InicioComponent {
  authService = inject(AuthService);
}
