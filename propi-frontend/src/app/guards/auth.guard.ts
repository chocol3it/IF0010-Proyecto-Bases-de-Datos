import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../services/auth.service';
import { Rol } from '../models/auth.model';

// Solo deja pasar si hay sesión y, si la ruta define roles, si el usuario tiene uno de ellos.
// Es solo para la navegación: quien realmente valida los permisos es SQL Server.
export const authGuard: CanActivateFn = (route) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (!authService.token()) {
    return router.createUrlTree(['/login']);
  }
  const roles = route.data['roles'] as Rol[] | undefined;
  if (roles && !authService.tieneRol(...roles)) {
    return router.createUrlTree(['/inicio']);
  }
  return true;
};
