import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { TipoImpuesto, TipoImpuestoPayload } from '../models/tipo-impuesto.model';

@Injectable({
  providedIn: 'root',
})
export class TipoImpuestoService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}tipos-impuesto`;

  obtenerTiposImpuesto(): Observable<TipoImpuesto[]> {
    return this.http.get<TipoImpuesto[]>(this.baseUrl);
  }

  obtenerTipoImpuesto(id: number): Observable<TipoImpuesto> {
    return this.http.get<TipoImpuesto>(`${this.baseUrl}/${id}`);
  }

  crearTipoImpuesto(datos: TipoImpuestoPayload): Observable<TipoImpuesto> {
    return this.http.post<TipoImpuesto>(this.baseUrl, datos);
  }

  actualizarTipoImpuesto(id: number, datos: TipoImpuestoPayload): Observable<TipoImpuesto> {
    return this.http.put<TipoImpuesto>(`${this.baseUrl}/${id}`, datos);
  }

  eliminarTipoImpuesto(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
