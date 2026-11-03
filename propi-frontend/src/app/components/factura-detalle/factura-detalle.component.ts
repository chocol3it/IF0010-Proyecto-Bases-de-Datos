import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FacturaService } from '../../services/factura.service';
import { NotaService } from '../../services/nota.service';
import { CatalogoService } from '../../services/catalogo.service';
import { AuthService } from '../../services/auth.service';
import { Factura, FacturaDetalle } from '../../models/factura.model';
import { Nota } from '../../models/nota.model';
import { Catalogo } from '../../models/catalogo.model';

// Muestra la factura con sus líneas y sus notas. El administrador puede modificar
// los datos que no afectan montos y eliminar la factura.
@Component({
  selector: 'app-factura-detalle',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './factura-detalle.component.html',
})
export class FacturaDetalleComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private facturaService = inject(FacturaService);
  private notaService = inject(NotaService);
  private catalogoService = inject(CatalogoService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  authService = inject(AuthService);

  codFactura = Number(this.route.snapshot.paramMap.get('id'));
  factura = signal<Factura | null>(null);
  detalle = signal<FacturaDetalle[]>([]);
  notas = signal<Nota[]>([]);
  condiciones = signal<Catalogo[]>([]);
  mediosPago = signal<Catalogo[]>([]);
  mensaje = signal('');

  form = this.fb.group({
    codCondicionVenta: [0, Validators.min(1)],
    codMedioPago: [0, Validators.min(1)],
    desObservaciones: ['', Validators.maxLength(500)],
  });

  ngOnInit(): void {
    this.facturaService.obtenerFactura(this.codFactura).subscribe({
      next: (factura) => {
        this.factura.set(factura);
        this.form.patchValue(factura);
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo cargar la factura.'),
    });
    this.facturaService.obtenerDetalle(this.codFactura).subscribe((data) => this.detalle.set(data));
    this.notaService.obtenerNotas(this.codFactura).subscribe((data) => this.notas.set(data));

    if (this.authService.tieneRol('ADMINISTRADOR')) {
      this.catalogoService.listar('condiciones-venta').subscribe((data) => this.condiciones.set(data));
      this.catalogoService.listar('medios-pago').subscribe((data) => this.mediosPago.set(data));
    }
  }

  actualizar(): void {
    this.facturaService.actualizarFactura(this.codFactura, this.form.getRawValue()).subscribe({
      next: (factura) => {
        this.factura.set(factura);
        this.mensaje.set('Factura actualizada.');
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo actualizar la factura.'),
    });
  }

  eliminar(): void {
    if (!confirm(`¿Eliminar la factura ${this.codFactura} con todas sus líneas?`)) {
      return;
    }
    this.facturaService.eliminarFactura(this.codFactura).subscribe({
      next: () => this.router.navigate(['/facturas']),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo eliminar la factura.'),
    });
  }
}
