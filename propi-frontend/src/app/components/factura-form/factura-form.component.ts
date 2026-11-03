import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { FacturaService } from '../../services/factura.service';
import { ClienteService } from '../../services/cliente.service';
import { ProductoService } from '../../services/producto.service';
import { CatalogoService } from '../../services/catalogo.service';
import { Catalogo } from '../../models/catalogo.model';
import { Cliente } from '../../models/cliente.model';
import { Producto } from '../../models/producto.model';

// Registro de factura con sus líneas (FormArray, como en el lab 11).
// Solo se envían producto y cantidad: el procedimiento almacenado calcula los montos
// y guarda la factura con todas sus líneas en una sola transacción.
@Component({
  selector: 'app-factura-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './factura-form.component.html',
})
export class FacturaFormComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private facturaService = inject(FacturaService);
  private clienteService = inject(ClienteService);
  private productoService = inject(ProductoService);
  private catalogoService = inject(CatalogoService);
  private router = inject(Router);

  clientes = signal<Cliente[]>([]);
  productos = signal<Producto[]>([]);
  condiciones = signal<Catalogo[]>([]);
  mediosPago = signal<Catalogo[]>([]);
  monedas = signal<Catalogo[]>([]);
  mensaje = signal('');
  guardando = signal(false);

  form = this.fb.group({
    codCliente: [0, Validators.min(1)],
    codCondicionVenta: [0, Validators.min(1)],
    codMedioPago: [0, Validators.min(1)],
    codMoneda: [0, Validators.min(1)],
    monTipoCambio: [1, [Validators.required, Validators.min(0.0001)]],
    desObservaciones: ['', Validators.maxLength(500)],
    lineas: this.fb.array([this.crearLinea()]),
  });

  get lineas() {
    return this.form.controls.lineas;
  }

  ngOnInit(): void {
    // Solo clientes y productos activos se pueden facturar
    this.clienteService.obtenerClientes().subscribe((data) => this.clientes.set(data.filter((c) => c.codEstado === 'A')));
    this.productoService.obtenerProductos().subscribe((data) => this.productos.set(data.filter((p) => p.codEstado === 'A')));
    this.catalogoService.listar('condiciones-venta').subscribe((data) => this.condiciones.set(data));
    this.catalogoService.listar('medios-pago').subscribe((data) => this.mediosPago.set(data));
    this.catalogoService.listar('monedas').subscribe((data) => this.monedas.set(data));
  }

  crearLinea() {
    return this.fb.group({
      codProducto: [0, Validators.min(1)],
      canCantidad: [1, [Validators.required, Validators.min(0.01)]],
    });
  }

  agregarLinea(): void {
    this.lineas.push(this.crearLinea());
  }

  quitarLinea(indice: number): void {
    if (this.lineas.length > 1) {
      this.lineas.removeAt(indice);
    }
  }

  // Vista previa del total; el monto oficial lo calcula el procedimiento almacenado
  totalEstimado(): number {
    let total = 0;
    for (const linea of this.lineas.getRawValue()) {
      const producto = this.productos().find((p) => p.codProducto === linea.codProducto);
      if (producto) {
        total += linea.canCantidad * producto.monPrecio * (1 + producto.porImpuesto / 100);
      }
    }
    return total;
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.mensaje.set('Complete todos los campos y las líneas de la factura.');
      return;
    }
    this.guardando.set(true);
    this.facturaService.crearFactura(this.form.getRawValue()).subscribe({
      next: (factura) => this.router.navigate(['/facturas', factura.codFactura]),
      error: (err) => {
        this.guardando.set(false);
        this.mensaje.set(err.error?.detail ?? 'No se pudo registrar la factura.');
      },
    });
  }
}
