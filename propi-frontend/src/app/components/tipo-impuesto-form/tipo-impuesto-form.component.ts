import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TipoImpuestoService } from '../../services/tipo-impuesto.service';

@Component({
  selector: 'app-tipo-impuesto-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './tipo-impuesto-form.component.html',
})
export class TipoImpuestoFormComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private tipoImpuestoService = inject(TipoImpuestoService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  codTipoImpuesto: number | null = null;
  mensaje = signal('');

  form = this.fb.group({
    codTarifa: ['', [Validators.required, Validators.pattern(/^\d{2}$/)]],
    desTipoImpuesto: ['', [Validators.required, Validators.maxLength(100)]],
    porImpuesto: [0, [Validators.required, Validators.min(0), Validators.max(100)]],
    codEstado: ['A', Validators.required],
  });

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.codTipoImpuesto = Number(id);
      this.tipoImpuestoService.obtenerTipoImpuesto(this.codTipoImpuesto).subscribe({
        next: (tipo) => this.form.patchValue(tipo),
        error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo cargar el tipo de impuesto.'),
      });
    }
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const datos = this.form.getRawValue();
    const peticion = this.codTipoImpuesto
      ? this.tipoImpuestoService.actualizarTipoImpuesto(this.codTipoImpuesto, datos)
      : this.tipoImpuestoService.crearTipoImpuesto(datos);

    peticion.subscribe({
      next: () => this.router.navigate(['/tipos-impuesto']),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo guardar.'),
    });
  }
}
