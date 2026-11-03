import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { ProductoService } from '../../services/producto.service';
import { Producto } from '../../models/producto.model';

@Component({
  selector: 'app-producto-list',
  imports: [CommonModule, RouterLink],
  templateUrl: './producto-list.component.html',
})
export class ProductoListComponent implements OnInit {
  private productoService = inject(ProductoService);

  productos = signal<Producto[]>([]);
  mensaje = signal('');

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.productoService.obtenerProductos().subscribe({
      next: (data) => this.productos.set(data),
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudieron cargar los productos.'),
    });
  }

  eliminar(producto: Producto): void {
    if (!confirm(`¿Eliminar el producto ${producto.desProducto}?`)) {
      return;
    }
    this.productoService.eliminarProducto(producto.codProducto).subscribe({
      next: () => {
        this.mensaje.set('Producto eliminado.');
        this.cargar();
      },
      error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo eliminar.'),
    });
  }
}
