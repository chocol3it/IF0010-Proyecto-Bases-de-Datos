import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NotaService } from '../../services/nota.service';
import { AuthService } from '../../services/auth.service';
import { Nota } from '../../models/nota.model';

@Component({
  selector: 'app-nota-list',
  imports: [CommonModule, RouterLink],
  templateUrl: './nota-list.component.html',
})
export class NotaListComponent implements OnInit {
  private notaService = inject(NotaService);
  authService = inject(AuthService);

  notas = signal<Nota[]>([]);
  mensaje = signal('');

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.notaService.obtenerNotas().subscribe({
      next: (data) => this.notas.set(data),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudieron cargar las notas.'),
    });
  }

  eliminar(nota: Nota): void {
    if (!confirm(`¿Eliminar la nota ${nota.codNota}?`)) {
      return;
    }
    this.notaService.eliminarNota(nota.codNota).subscribe({
      next: () => {
        this.mensaje.set('Nota eliminada.');
        this.cargar();
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo eliminar la nota.'),
    });
  }
}
