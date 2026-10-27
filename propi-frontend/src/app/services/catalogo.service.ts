import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Estado, TipoIdentificacion } from '../models/cliente.model';

@Injectable({
  providedIn: 'root',
})
export class CatalogoService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}catalogos`;

  obtenerEstados(): Observable<Estado[]> {
    return this.http.get<Estado[]>(`${this.baseUrl}/estados`);
  }

  obtenerTiposIdentificacion(): Observable<TipoIdentificacion[]> {
    return this.http.get<TipoIdentificacion[]>(`${this.baseUrl}/tipos-identificacion`);
  }
}
