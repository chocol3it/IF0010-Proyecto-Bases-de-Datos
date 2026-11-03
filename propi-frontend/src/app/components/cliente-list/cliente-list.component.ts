import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { ClienteService } from '../../services/cliente.service';
import { AuthService } from '../../services/auth.service';
import { Cliente } from '../../models/cliente.model';

@Component({
  selector: 'app-cliente-list',
  imports: [CommonModule, RouterLink],
  templateUrl: './cliente-list.component.html',
})
export class ClienteListComponent implements OnInit {
  private clienteService = inject(ClienteService);
  authService = inject(AuthService);

  clientes = signal<Cliente[]>([]);
  mensaje = signal('');

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.clienteService.obtenerClientes().subscribe({
      next: (data) => this.clientes.set(data),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudieron cargar los clientes.'),
    });
  }

  eliminar(cliente: Cliente): void {
    if (!confirm(`¿Eliminar al cliente ${cliente.nomCliente}?`)) {
      return;
    }
    this.clienteService.eliminarCliente(cliente.codCliente).subscribe({
      next: () => {
        this.mensaje.set('Cliente eliminado.');
        this.cargar();
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo eliminar el cliente.'),
    });
  }
}
