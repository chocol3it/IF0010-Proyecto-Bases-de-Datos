import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { FilaReporte, ReporteService, TipoReporte } from '../../services/reporte.service';

// REQ 007: los 4 reportes en una sola pantalla. Las columnas de la tabla salen
// de las filas que devuelve cada procedimiento almacenado.
@Component({
  selector: 'app-reportes',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './reportes.component.html',
})
export class ReportesComponent {
  private fb = inject(NonNullableFormBuilder);
  private reporteService = inject(ReporteService);

  // Encabezados legibles para las columnas que devuelven los procedimientos
  readonly titulos: Record<string, string> = {
    nom_cliente: 'Cliente',
    num_identificacion: 'Identificación',
    des_actividad_economica: 'Actividad económica',
    des_correo: 'Correo',
    num_telefono: 'Teléfono',
    cod_factura: 'N.º factura',
    fec_factura: 'Fecha',
    mon_subtotal: 'Subtotal',
    mon_total_impuestos: 'Total impuestos',
    mon_total: 'Total factura',
    fec_registro: 'Fecha de registro',
    des_accion: 'Acción',
    cod_usuario: 'Usuario',
    cod_tabla: 'Tabla afectada',
    cod_llave: 'Llave',
    des_datos: 'Datos afectados',
    nom_usuario: 'Usuario',
    nom_rol: 'Rol',
    nom_objeto: 'Objeto',
    des_tipo_objeto: 'Tipo de objeto',
    des_permiso: 'Permiso',
    des_estado_permiso: 'Estado',
  };

  filas = signal<FilaReporte[]>([]);
  columnas = signal<string[]>([]);
  mensaje = signal('');

  form = this.fb.group({
    tipo: ['clientes' as TipoReporte],
    desde: [this.hoy(-30)],
    hasta: [this.hoy(0)],
    estado: [''],
    usuario: [''],
  });

  generar(): void {
    const { tipo, desde, hasta, estado, usuario } = this.form.getRawValue();
    this.mensaje.set('');
    this.reporteService.generar(tipo, { desde, hasta, estado, usuario }).subscribe({
      next: (data) => {
        this.filas.set(data);
        this.columnas.set(data.length > 0 ? Object.keys(data[0]) : []);
        if (data.length === 0) {
          this.mensaje.set('El reporte no tiene resultados para esos filtros.');
        }
      },
      error: (err) => {
        this.filas.set([]);
        this.mensaje.set(err.error?.detail ?? 'No se pudo generar el reporte.');
      },
    });
  }

  // Fecha de hoy (más o menos días) en formato yyyy-MM-dd para los <input type="date">
  private hoy(dias: number): string {
    const fecha = new Date();
    fecha.setDate(fecha.getDate() + dias);
    return fecha.toISOString().substring(0, 10);
  }
}
