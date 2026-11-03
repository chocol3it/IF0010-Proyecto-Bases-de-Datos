export type Rol = 'ADMINISTRADOR' | 'DIGITADOR' | 'CONSULTA';

export interface LoginRespuesta {
  token: string;
  usuario: string;
  rol: Rol;
}
