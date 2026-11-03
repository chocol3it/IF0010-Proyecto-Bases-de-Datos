import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

// El usuario y la contraseña son un login de SQL Server (REQ 003)
@Component({
  selector: 'app-login',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
})
export class LoginComponent {
  private fb = inject(NonNullableFormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  mensaje = signal('');
  ingresando = signal(false);

  form = this.fb.group({
    usuario: ['', Validators.required],
    contrasena: ['', Validators.required],
  });

  ingresar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.ingresando.set(true);
    const { usuario, contrasena } = this.form.getRawValue();
    this.authService.login(usuario, contrasena).subscribe({
      next: () => this.router.navigate(['/inicio']),
      error: (err) => {
        this.ingresando.set(false);
        this.mensaje.set(err.error?.detail ?? 'No se pudo iniciar sesión.');
      },
    });
  }
}
