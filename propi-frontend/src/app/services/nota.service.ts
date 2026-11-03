import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Nota, NotaPayload } from '../models/nota.model';

@Injectable({
  providedIn: 'root',
})
export class NotaService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}notas`;

  // Sin factura devuelve todas las notas
  obtenerNotas(codFactura?: number): Observable<Nota[]> {
    const params: Record<string, number> = codFactura ? { factura: codFactura } : {};
    return this.http.get<Nota[]>(this.baseUrl, { params });
  }

  obtenerNota(id: number): Observable<Nota> {
    return this.http.get<Nota>(`${this.baseUrl}/${id}`);
  }

  crearNota(datos: NotaPayload): Observable<Nota> {
    return this.http.post<Nota>(this.baseUrl, datos);
  }

  actualizarNota(id: number, datos: NotaPayload): Observable<Nota> {
    return this.http.put<Nota>(`${this.baseUrl}/${id}`, datos);
  }

  eliminarNota(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
