import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Producto, ProductoPayload } from '../models/producto.model';

@Injectable({
  providedIn: 'root',
})
export class ProductoService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}productos`;

  obtenerProductos(): Observable<Producto[]> {
    return this.http.get<Producto[]>(this.baseUrl);
  }

  obtenerProducto(id: number): Observable<Producto> {
    return this.http.get<Producto>(`${this.baseUrl}/${id}`);
  }

  crearProducto(datos: ProductoPayload): Observable<Producto> {
    return this.http.post<Producto>(this.baseUrl, datos);
  }

  actualizarProducto(id: number, datos: ProductoPayload): Observable<Producto> {
    return this.http.put<Producto>(`${this.baseUrl}/${id}`, datos);
  }

  eliminarProducto(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
