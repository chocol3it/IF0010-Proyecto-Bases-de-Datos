import { Routes } from '@angular/router';
import { ClienteListComponent } from './components/cliente-list/cliente-list.component';
import { ClienteFormComponent } from './components/cliente-form/cliente-form.component';

export const routes: Routes = [
  { path: '', redirectTo: 'clientes', pathMatch: 'full' },
  { path: 'clientes', component: ClienteListComponent },
  { path: 'clientes/nuevo', component: ClienteFormComponent },
  { path: 'clientes/:id/editar', component: ClienteFormComponent },
  { path: '**', redirectTo: 'clientes' },
];
