export interface Linea {
  codProducto: number;
  canCantidad: number;
}

// Lo que se envía al registrar: los montos los calcula el procedimiento almacenado
export interface FacturaPayload {
  codCliente: number;
  codCondicionVenta: number;
  codMedioPago: number;
  codMoneda: number;
  monTipoCambio: number;
  desObservaciones: string;
  lineas: Linea[];
}

export interface FacturaActualizarPayload {
  codCondicionVenta: number;
  codMedioPago: number;
  desObservaciones: string;
}

export interface Factura {
  codFactura: number;
  codCliente: number;
  nomCliente: string;
  fecFactura: string;
  codCondicionVenta: number;
  desCondicionVenta: string;
  codMedioPago: number;
  desMedioPago: string;
  codMoneda: number;
  codIso: string;
  monTipoCambio: number;
  desObservaciones: string;
  monSubtotal: number;
  monTotalImpuestos: number;
  monTotal: number;
}

export interface FacturaDetalle {
  codDetalle: number;
  codProducto: number;
  codCabys: string;
  desProducto: string;
  canCantidad: number;
  monPrecioUnitario: number;
  monImpuesto: number;
  monLinea: number;
}
