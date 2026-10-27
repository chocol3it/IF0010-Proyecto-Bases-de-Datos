export interface ClientePayload {
  nomCliente: string;
  codTipoIdentificacion: number;
  numIdentificacion: string;
  desProvincia: string;
  desCanton: string;
  desDistrito: string;
  desBarrio: string;
  desProfesion: string;
  desActividadEconomica: string;
  desCorreo: string;
  numTelefono: string;
  codEstado: string;
}

export interface Cliente extends ClientePayload {
  codCliente: number;
  fecRegistro: string;
}

export interface TipoIdentificacion {
  codTipoIdentificacion: number;
  desTipoIdentificacion: string;
}

export interface Estado {
  codEstado: string;
  desEstado: string;
}
