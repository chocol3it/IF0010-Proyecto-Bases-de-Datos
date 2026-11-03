import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { NotaService } from '../../services/nota.service';
import { FacturaService } from '../../services/factura.service';
import { CatalogoService } from '../../services/catalogo.service';
import { Catalogo } from '../../models/catalogo.model';
import { Factura } from '../../models/factura.model';

// Crear (/notas/nueva?factura=5) y editar (/notas/:id/editar) una nota
@Component({
  selector: 'app-nota-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './nota-form.component.html',
})
export class NotaFormComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private notaService = inject(NotaService);
  private facturaService = inject(FacturaService);
  private catalogoService = inject(CatalogoService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  codNota: number | null = null;
  facturas = signal<Factura[]>([]);
  tiposNota = signal<Catalogo[]>([]);
  mensaje = signal('');

  form = this.fb.group({
    codFactura: [Number(this.route.snapshot.queryParamMap.get('factura') ?? 0), Validators.min(1)],
    codTipoNota: [0, Validators.min(1)],
    desMotivo: ['', [Validators.required, Validators.maxLength(300)]],
    monNota: [0, [Validators.required, Validators.min(0.01)]],
  });

  ngOnInit(): void {
    this.facturaService.obtenerFacturas().subscribe((data) => this.facturas.set(data));
    this.catalogoService.listar('tipos-nota').subscribe((data) => this.tiposNota.set(data));

    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.codNota = Number(id);
      this.form.controls.codFactura.disable(); // la factura de una nota no cambia
      this.notaService.obtenerNota(this.codNota).subscribe({
        next: (nota) => this.form.patchValue(nota),
        error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo cargar la nota.'),
      });
    }
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const datos = this.form.getRawValue();
    const peticion = this.codNota
      ? this.notaService.actualizarNota(this.codNota, datos)
      : this.notaService.crearNota(datos);

    peticion.subscribe({
      next: () => this.router.navigate(['/facturas', datos.codFactura]),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo guardar la nota.'),
    });
  }
}
