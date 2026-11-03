export interface ProductoPayload {
  codCabys: string;
  desProducto: string;
  codUnidadMedida: number;
  monPrecio: number;
  codTipoImpuesto: number;
  codEstado: string;
}

export interface Producto extends ProductoPayload {
  codProducto: number;
  desUnidadMedida: string;
  desTipoImpuesto: string;
  porImpuesto: number;
}
