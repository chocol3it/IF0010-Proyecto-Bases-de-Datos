import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';
import { LoginRespuesta, Rol } from '../models/auth.model';

// Guarda el token, el usuario y el rol en sessionStorage (igual que en el lab 8).
@Injectable({
  providedIn: 'root',
})
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);
  private readonly baseUrl = `${environment.API_URL}auth`;

  usuario = signal(sessionStorage.getItem('usuario') ?? '');
  rol = signal((sessionStorage.getItem('rol') ?? '') as Rol | '');

  login(usuario: string, contrasena: string): Observable<LoginRespuesta> {
    return this.http.post<LoginRespuesta>(`${this.baseUrl}/login`, { usuario, contrasena }).pipe(
      tap((respuesta) => {
        sessionStorage.setItem('token', respuesta.token);
        sessionStorage.setItem('usuario', respuesta.usuario);
        sessionStorage.setItem('rol', respuesta.rol);
        this.usuario.set(respuesta.usuario);
        this.rol.set(respuesta.rol);
      }),
    );
  }

  // Registra la salida en la bitácora y limpia la sesión aunque la petición falle
  logout(): void {
    this.http.post(`${this.baseUrl}/logout`, {}).subscribe({
      complete: () => this.limpiarSesion(),
      error: () => this.limpiarSesion(),
    });
  }

  limpiarSesion(): void {
    sessionStorage.clear();
    this.usuario.set('');
    this.rol.set('');
    this.router.navigate(['/login']);
  }

  token(): string | null {
    return sessionStorage.getItem('token');
  }

  tieneRol(...roles: Rol[]): boolean {
    return roles.includes(this.rol() as Rol);
  }
}
