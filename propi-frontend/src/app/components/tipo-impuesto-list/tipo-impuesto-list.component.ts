import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TipoImpuestoService } from '../../services/tipo-impuesto.service';
import { TipoImpuesto } from '../../models/tipo-impuesto.model';

@Component({
  selector: 'app-tipo-impuesto-list',
  imports: [CommonModule, RouterLink],
  templateUrl: './tipo-impuesto-list.component.html',
})
export class TipoImpuestoListComponent implements OnInit {
  private tipoImpuestoService = inject(TipoImpuestoService);

  tipos = signal<TipoImpuesto[]>([]);
  mensaje = signal('');

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.tipoImpuestoService.obtenerTiposImpuesto().subscribe({
      next: (data) => this.tipos.set(data),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudieron cargar los tipos de impuesto.'),
    });
  }

  eliminar(tipo: TipoImpuesto): void {
    if (!confirm(`¿Eliminar el impuesto ${tipo.desTipoImpuesto}?`)) {
      return;
    }
    this.tipoImpuestoService.eliminarTipoImpuesto(tipo.codTipoImpuesto).subscribe({
      next: () => {
        this.mensaje.set('Tipo de impuesto eliminado.');
        this.cargar();
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo eliminar.'),
    });
  }
}
