import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FacturaService } from '../../services/factura.service';
import { Factura } from '../../models/factura.model';

@Component({
  selector: 'app-factura-list',
  imports: [CommonModule, RouterLink],
  templateUrl: './factura-list.component.html',
})
export class FacturaListComponent implements OnInit {
  private facturaService = inject(FacturaService);

  facturas = signal<Factura[]>([]);
  mensaje = signal('');

  ngOnInit(): void {
    this.facturaService.obtenerFacturas().subscribe({
      next: (data) => this.facturas.set(data),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudieron cargar las facturas.'),
    });
  }
}
