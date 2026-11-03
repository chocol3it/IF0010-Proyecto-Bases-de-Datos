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
  desTipoIdentificacion: string;
  fecRegistro: string;
}
