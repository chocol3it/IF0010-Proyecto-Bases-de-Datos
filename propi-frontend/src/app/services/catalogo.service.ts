import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Catalogo } from '../models/catalogo.model';

export type NombreCatalogo =
  | 'estados'
  | 'tipos-identificacion'
  | 'condiciones-venta'
  | 'medios-pago'
  | 'monedas'
  | 'unidades-medida'
  | 'tipos-nota';

@Injectable({
  providedIn: 'root',
})
export class CatalogoService {
  private http = inject(HttpClient);
  private readonly baseUrl = `${environment.API_URL}catalogos`;

  listar(nombre: NombreCatalogo): Observable<Catalogo[]> {
    return this.http.get<Catalogo[]>(`${this.baseUrl}/${nombre}`);
  }
}
