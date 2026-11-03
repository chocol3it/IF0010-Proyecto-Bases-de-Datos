export interface NotaPayload {
  codFactura: number;
  codTipoNota: number;
  desMotivo: string;
  monNota: number;
}

export interface Nota extends NotaPayload {
  codNota: number;
  fecNota: string;
  desTipoNota: string;
}
