import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { LoginComponent } from './components/login/login.component';
import { InicioComponent } from './components/inicio/inicio.component';
import { ClienteListComponent } from './components/cliente-list/cliente-list.component';
import { ClienteFormComponent } from './components/cliente-form/cliente-form.component';
import { TipoImpuestoListComponent } from './components/tipo-impuesto-list/tipo-impuesto-list.component';
import { TipoImpuestoFormComponent } from './components/tipo-impuesto-form/tipo-impuesto-form.component';
import { ProductoListComponent } from './components/producto-list/producto-list.component';
import { ProductoFormComponent } from './components/producto-form/producto-form.component';
import { FacturaListComponent } from './components/factura-list/factura-list.component';
import { FacturaFormComponent } from './components/factura-form/factura-form.component';
import { FacturaDetalleComponent } from './components/factura-detalle/factura-detalle.component';
import { NotaListComponent } from './components/nota-list/nota-list.component';
import { NotaFormComponent } from './components/nota-form/nota-form.component';
import { ReportesComponent } from './components/reportes/reportes.component';

// data.roles: qué roles ven cada módulo (REQ 004). Es solo navegación:
// si alguien llama la API sin permiso, SQL Server la rechaza (REQ 008).
const ADMIN_DIGITADOR = { roles: ['ADMINISTRADOR', 'DIGITADOR'] };
const ADMIN = { roles: ['ADMINISTRADOR'] };
const ADMIN_CONSULTA = { roles: ['ADMINISTRADOR', 'CONSULTA'] };

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: '', redirectTo: 'inicio', pathMatch: 'full' },
  { path: 'inicio', component: InicioComponent, canActivate: [authGuard] },

  { path: 'clientes', component: ClienteListComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'clientes/nuevo', component: ClienteFormComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'clientes/:id/editar', component: ClienteFormComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },

  { path: 'tipos-impuesto', component: TipoImpuestoListComponent, canActivate: [authGuard], data: ADMIN },
  { path: 'tipos-impuesto/nuevo', component: TipoImpuestoFormComponent, canActivate: [authGuard], data: ADMIN },
  { path: 'tipos-impuesto/:id/editar', component: TipoImpuestoFormComponent, canActivate: [authGuard], data: ADMIN },

  { path: 'productos', component: ProductoListComponent, canActivate: [authGuard], data: ADMIN },
  { path: 'productos/nuevo', component: ProductoFormComponent, canActivate: [authGuard], data: ADMIN },
  { path: 'productos/:id/editar', component: ProductoFormComponent, canActivate: [authGuard], data: ADMIN },

  { path: 'facturas', component: FacturaListComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'facturas/nueva', component: FacturaFormComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'facturas/:id', component: FacturaDetalleComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },

  { path: 'notas', component: NotaListComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'notas/nueva', component: NotaFormComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },
  { path: 'notas/:id/editar', component: NotaFormComponent, canActivate: [authGuard], data: ADMIN_DIGITADOR },

  { path: 'reportes', component: ReportesComponent, canActivate: [authGuard], data: ADMIN_CONSULTA },

  { path: '**', redirectTo: 'inicio' },
];
