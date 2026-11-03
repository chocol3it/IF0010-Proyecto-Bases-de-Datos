export interface TipoImpuestoPayload {
  codTarifa: string;
  desTipoImpuesto: string;
  porImpuesto: number;
  codEstado: string;
}

export interface TipoImpuesto extends TipoImpuestoPayload {
  codTipoImpuesto: number;
}
