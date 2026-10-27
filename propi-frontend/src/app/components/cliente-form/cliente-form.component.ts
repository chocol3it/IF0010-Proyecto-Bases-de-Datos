import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ClienteService } from '../../services/cliente.service';
import { CatalogoService } from '../../services/catalogo.service';
import { Estado, TipoIdentificacion } from '../../models/cliente.model';

// Un solo formulario para crear (/clientes/nuevo) y editar (/clientes/:id/editar).
@Component({
  selector: 'app-cliente-form',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './cliente-form.component.html',
  styleUrl: './cliente-form.component.css',
})
export class ClienteFormComponent implements OnInit {
  private fb = inject(NonNullableFormBuilder);
  private clienteService = inject(ClienteService);
  private catalogoService = inject(CatalogoService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  codCliente: number | null = null;
  tiposIdentificacion = signal<TipoIdentificacion[]>([]);
  estados = signal<Estado[]>([]);
  mensaje = signal('');
  guardando = signal(false);

  form = this.fb.group({
    nomCliente: ['', [Validators.required, Validators.maxLength(150)]],
    codTipoIdentificacion: [0, [Validators.required, Validators.min(1)]],
    numIdentificacion: ['', [Validators.required, Validators.maxLength(20)]],
    desProvincia: ['', [Validators.required, Validators.maxLength(50)]],
    desCanton: ['', [Validators.required, Validators.maxLength(50)]],
    desDistrito: ['', [Validators.required, Validators.maxLength(50)]],
    desBarrio: ['', Validators.maxLength(100)],
    desProfesion: ['', Validators.maxLength(100)],
    desActividadEconomica: ['', Validators.maxLength(150)],
    desCorreo: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
    numTelefono: ['', [Validators.required, Validators.maxLength(20)]],
    codEstado: ['A', Validators.required],
  });

  ngOnInit(): void {
    this.catalogoService.obtenerTiposIdentificacion().subscribe((data) => this.tiposIdentificacion.set(data));
    this.catalogoService.obtenerEstados().subscribe((data) => this.estados.set(data));

    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.codCliente = Number(id);
      this.clienteService.obtenerCliente(this.codCliente).subscribe({
        next: (cliente) => this.form.patchValue(cliente),
        error: (err) => this.mensaje.set(err.error?.detail ?? 'No se pudo cargar el cliente.'),
      });
    }
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.guardando.set(true);
    const datos = this.form.getRawValue();
    const peticion = this.codCliente
      ? this.clienteService.actualizarCliente(this.codCliente, datos)
      : this.clienteService.crearCliente(datos);

    peticion.subscribe({
      next: () => this.router.navigate(['/clientes']),
      error: (err) => {
        this.guardando.set(false);
        this.mensaje.set(err.error?.detail ?? 'No se pudo guardar el cliente.');
      },
    });
  }

  invalido(campo: string): boolean {
    const control = this.form.get(campo);
    return !!control && control.invalid && control.touched;
  }
}
