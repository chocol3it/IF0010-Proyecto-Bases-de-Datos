package cr.ac.ucr.paraiso.ie.c4h877.propi.business;

import cr.ac.ucr.paraiso.ie.c4h877.propi.data.ProductoRepository;
import cr.ac.ucr.paraiso.ie.c4h877.propi.domain.Producto;
import cr.ac.ucr.paraiso.ie.c4h877.propi.dto.ProductoDTO;
import cr.ac.ucr.paraiso.ie.c4h877.propi.exception.ResourceNotFoundException;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;

    public ProductoService(ProductoRepository productoRepository) {
        this.productoRepository = productoRepository;
    }

    public List<Producto> listar() {
        return productoRepository.consultar(null);
    }

    public Producto obtener(Integer codProducto) {
        return productoRepository.consultar(codProducto).stream().findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("Producto " + codProducto + " no encontrado"));
    }

    public Producto crear(ProductoDTO producto) {
        return productoRepository.insertar(producto);
    }

    public Producto actualizar(Integer codProducto, ProductoDTO producto) {
        return productoRepository.actualizar(codProducto, producto);
    }

    public void eliminar(Integer codProducto) {
        productoRepository.eliminar(codProducto);
    }
}
