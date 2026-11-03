import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ProductoService } from '../../services/producto.service';
import { TipoImpuestoService } from '../../services/tipo-impuesto.service';
import { CatalogoService } from '../../services/catalogo.service';
import { Catalogo } from '../../models/catalogo.model';
import { TipoImpuesto } from '../../models/tipo-impuesto.model';

@Component({
  selector: 'app-producto-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './producto-form.component.html',
})
export class ProductoFormComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private productoService = inject(ProductoService);
  private tipoImpuestoService = inject(TipoImpuestoService);
  private catalogoService = inject(CatalogoService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  codProducto: number | null = null;
  unidades = signal<Catalogo[]>([]);
  impuestos = signal<TipoImpuesto[]>([]);
  mensaje = signal('');

  form = this.fb.group({
    codCabys: ['', [Validators.required, Validators.pattern(/^\d{13}$/)]],
    desProducto: ['', [Validators.required, Validators.maxLength(200)]],
    codUnidadMedida: [0, [Validators.required, Validators.min(1)]],
    monPrecio: [0, [Validators.required, Validators.min(0)]],
    codTipoImpuesto: [0, [Validators.required, Validators.min(1)]],
    codEstado: ['A', Validators.required],
  });

  ngOnInit(): void {
    this.catalogoService.listar('unidades-medida').subscribe((data) => this.unidades.set(data));
    this.tipoImpuestoService.obtenerTiposImpuesto().subscribe((data) => this.impuestos.set(data));

    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.codProducto = Number(id);
      this.productoService.obtenerProducto(this.codProducto).subscribe({
        next: (producto) => this.form.patchValue(producto),
        error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo cargar el producto.'),
      });
    }
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const datos = this.form.getRawValue();
    const peticion = this.codProducto
      ? this.productoService.actualizarProducto(this.codProducto, datos)
      : this.productoService.crearProducto(datos);

    peticion.subscribe({
      next: () => this.router.navigate(['/productos']),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo guardar.'),
    });
  }
}
