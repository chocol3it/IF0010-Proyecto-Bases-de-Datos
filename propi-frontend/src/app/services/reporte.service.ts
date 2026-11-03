import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export type TipoReporte = 'clientes' | 'facturas' | 'auditoria' | 'seguridad';

// Cada fila llega tal cual la devuelve el procedimiento (nombre de columna -> valor)
export type FilaReporte = Record<string, unknown>;

@Injectable({
  providedIn: 'root',
})
export class ReporteService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}reportes`;

  // Los filtros vacíos no se envían (el procedimiento los toma como "todos")
  generar(tipo: TipoReporte, filtros: Record<string, string>): Observable<FilaReporte[]> {
    const params: Record<string, string> = {};
    for (const [clave, valor] of Object.entries(filtros)) {
      if (valor) {
        params[clave] = valor;
      }
    }
    return this.http.get<FilaReporte[]>(`${this.baseUrl}/${tipo}`, { params });
  }
}
