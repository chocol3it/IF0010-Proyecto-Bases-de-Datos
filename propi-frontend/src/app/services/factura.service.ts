import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  Factura,
  FacturaActualizarPayload,
  FacturaDetalle,
  FacturaPayload,
} from '../models/factura.model';

@Injectable({
  providedIn: 'root',
})
export class FacturaService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}facturas`;

  obtenerFacturas(): Observable<Factura[]> {
    return this.http.get<Factura[]>(this.baseUrl);
  }

  obtenerFactura(id: number): Observable<Factura> {
    return this.http.get<Factura>(`${this.baseUrl}/${id}`);
  }

  obtenerDetalle(id: number): Observable<FacturaDetalle[]> {
    return this.http.get<FacturaDetalle[]>(`${this.baseUrl}/${id}/detalle`);
  }

  crearFactura(datos: FacturaPayload): Observable<Factura> {
    return this.http.post<Factura>(this.baseUrl, datos);
  }

  actualizarFactura(id: number, datos: FacturaActualizarPayload): Observable<Factura> {
    return this.http.put<Factura>(`${this.baseUrl}/${id}`, datos);
  }

  eliminarFactura(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
