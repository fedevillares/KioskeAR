# 📱 Arquitectura - Mi Kiosco Stock App

## 🏗️ Estructura del Proyecto

```
lib/
├── main.dart                          # Entry point - Inicializa app con providers
├── models/                            # Modelos de datos
│   ├── product.dart                  # Producto con cálculos de stock y ganancia
│   ├── sale.dart                     # Registro de venta
│   ├── cart_item.dart                # Item del carrito
│   └── customer.dart                 # Datos del cliente
├── providers/                        # State management (Provider)
│   ├── theme_provider.dart          # Tema claro/oscuro
│   └── cart_provider.dart           # Estado del carrito
├── screens/                         # Pantallas/Páginas
│   ├── splash_screen.dart          # Splash inicial
│   ├── home_page.dart              # Inicio - Catálogo de productos
│   ├── cart_page.dart              # Carrito de compras
│   ├── sales_page.dart             # Historial de ventas
│   ├── dashboard_page.dart         # Resumen general
│   ├── statistics_page.dart        # Gráficos y análisis
│   ├── profitability_page.dart     # Rentabilidad por producto
│   ├── settings_page.dart          # Configuración
│   └── mercadopago_qr_page.dart    # QR de MercadoPago
├── services/                       # Lógica de negocio
│   ├── storage_service.dart       # Persistencia (SharedPreferences)
│   ├── mercadopago_service.dart   # Integración MercadoPago
│   └── backup_service.dart        # Exportación de datos
├── widgets/                       # Componentes reutilizables
│   ├── product_card.dart         # Tarjeta de producto
│   ├── category_chip.dart        # Filtro de categoría
│   ├── stock_counter.dart        # Selector de cantidad
│   └── add_product_dialog.dart   # Diálogo para agregar producto
└── utils/                        # Utilidades
    ├── constants.dart            # Constantes de la app
    ├── helpers.dart              # Funciones auxiliares
    └── security_helper.dart      # Utilidades de seguridad/encriptación
```

---

## 🔄 Flujo de Datos (Data Flow)

### 1. **Inicialización de la App** (main.dart)
```
main() 
  ↓
- SharedPreferences.getInstance()
- Orientación: portrait
- Transparencia: Edge-to-Edge
  ↓
MultiProvider:
  - ThemeProvider (Tema claro/oscuro)
  - CartProvider (Estado carrito)
  ↓
KioscoStockApp → SplashScreen
```

### 2. **Carga de Datos** (StorageService)
```
SharedPreferences (Local Storage)
  ├── "products" → JSON → List<Product>
  ├── "sales" → JSON → List<Sale>
  ├── "cart_items" → JSON → List<CartItem>
  └── Máximo 1000 ventas históricas
```

### 3. **Flujo de Compra**
```
home_page.dart (Catálogo)
  ↓ (usuario toca producto)
add_to_cart() 
  ↓
CartProvider._items (en memoria + SharedPreferences)
  ↓
cart_page.dart (Resumen)
  ↓
Completar venta → registrarSale()
  ↓
StorageService.saveSales() → producto.stock--
  ↓
Sincronizar home_page
```

---

## 📊 Modelos de Datos

### **Product**
```dart
class Product {
  String id;              // Identificador único
  String name;            // Nombre del producto
  String category;        // Categoría (Bebidas, Golosinas, etc.)
  int stock;              // Cantidad disponible
  double price;           // Precio de venta
  double costPrice;       // Precio de costo
  int minStock;           // Stock mínimo para alerta
  String? barcode;        // Código de barras
  String? imagePath;      // Ruta de imagen local
  DateTime createdAt;
  DateTime? lastUpdated;

  // Propiedades calculadas:
  bool get isLowStock => stock <= minStock;
  bool get isOutOfStock => stock == 0;
  double get profit => price - costPrice;
  double get profitMargin => ((price - costPrice) / costPrice) * 100;
  double get totalProfit => stock * profit;
}
```

### **Sale**
```dart
class Sale {
  String id;              // ID único de transacción
  String productId;
  String productName;
  int quantity;           // Cantidad vendida
  double pricePerUnit;
  double totalPrice;      // quantity * pricePerUnit
  DateTime timestamp;     // Cuándo se realizó
}
```

### **CartItem**
```dart
class CartItem {
  String productId;
  String productName;
  double price;           // Precio unitario
  int quantity;           // Cantidad en carrito
  
  double get total => price * quantity;
}
```

---

## 🔧 Servicios Principales

### **StorageService** (storage_service.dart)
**Responsabilidad:** Persistencia de datos

| Método | Parámetro | Retorna | Función |
|--------|-----------|---------|---------|
| `loadProducts()` | — | `List<Product>` | Carga productos de storage |
| `saveProducts(list)` | `List<Product>` | `bool` | Guarda lista de productos |
| `loadSales()` | — | `List<Sale>` | Carga historial de ventas |
| `saveSales(list)` | `List<Sale>` | `bool` | Guarda ventas (máx 1000) |
| `registerSale(sale)` | `Sale` | `bool` | Registra UNA venta nueva |
| `exportData()` | — | `String` (JSON) | Exporta todo para backup |
| `clearAllData()` | — | `bool` | Borra todo (⚠️ CUIDADO) |

### **CartProvider** (providers/cart_provider.dart)
**Responsabilidad:** Estado del carrito (Provider pattern)

| Propiedad/Método | Tipo | Función |
|------------------|------|---------|
| `_items` | `List<CartItem>` | Carrito en memoria |
| `total` | `double` | Suma de todos los totales |
| `itemCount` | `int` | Cantidad de líneas en carrito |
| `addToCart(product)` | void | Agrega o incrementa cantidad |
| `removeFromCart(id)` | void | Elimina producto del carrito |
| `updateQuantity(id, change)` | void | Suma/resta cantidad |
| `clearCart()` | void | Vacía el carrito |
| `_saveCart()` | async | Persiste en SharedPreferences |
| `_loadCart()` | async | Carga de SharedPreferences |

---

## 🎨 Pantallas Principales

### **home_page.dart** - Catálogo
- Listado de productos por categoría
- Filtro por categoría (CategoryChip)
- Card para cada producto (ProductCard)
- Botón "Agregar al carrito"
- Indicador de stock bajo/agotado

### **cart_page.dart** - Carrito
- Lista de CartItems
- Contador de cantidad (StockCounter)
- Botón eliminar por item
- Total de venta
- Botón "Finalizar venta"
- Integración con MercadoPago QR (opcional)

### **sales_page.dart** - Historial
- Tabla de ventas ordenadas por fecha
- Búsqueda/Filtros
- Totales y promedios
- Exportar a CSV/JSON

### **dashboard_page.dart** - Resumen
- Total de ingresos del día/mes
- Productos más vendidos
- Stock bajo alertas
- Última venta registrada

### **statistics_page.dart** - Análisis
- Gráficos (fl_chart)
- Ventas por categoría
- Evolución temporal
- Productos top sellers

### **profitability_page.dart** - Rentabilidad
- Margen de ganancia por producto
- Ganancia total en stock
- Proyecciones
- Reorden sugerido

---

## 🔌 Dependencias & Librerías

| Librería | Versión | Uso |
|----------|---------|-----|
| `flutter` | SDK | Framework principal |
| `provider` | 6.1.1 | State Management |
| `shared_preferences` | 2.2.2 | Persistencia local (clave-valor) |
| `intl` | 0.18.1 | Internacionalización (fechas, moneda) |
| `fl_chart` | 0.66.0 | Gráficos (BarChart, LineChart, etc.) |
| `image_picker` | 1.0.7 | Seleccionar imágenes de galería/cámara |
| `http` | 1.1.0 | Peticiones HTTP a APIs |
| `qr_flutter` | 4.1.0 | Generación de códigos QR |
| `encrypt` | 5.0.3 | Encriptación (datos sensibles) |
| `path_provider` | 2.1.1 | Rutas de documentos/cache del dispositivo |
| `share_plus` | 7.2.1 | Compartir archivos/datos |

---

## 🔐 Seguridad & Datos Sensibles

**security_helper.dart:**
- Encriptación con `encrypt` package
- Manejo de datos de MercadoPago
- Tokens y credenciales cifrados
- No guardar datos sin cifrar en SharedPreferences

---

## 💾 Persistencia - Estructura JSON

### **Productos almacenados:**
```json
{
  "id": "1",
  "name": "Coca Cola 500ml",
  "category": "Bebidas",
  "stock": 24,
  "price": 500.0,
  "costPrice": 300.0,
  "minStock": 10,
  "barcode": null,
  "imagePath": null,
  "createdAt": "2024-01-15T10:30:00.000Z",
  "lastUpdated": null
}
```

### **Ventas registradas:**
```json
{
  "id": "SALE_20240620_001",
  "productId": "1",
  "productName": "Coca Cola 500ml",
  "quantity": 2,
  "pricePerUnit": 500.0,
  "totalPrice": 1000.0,
  "timestamp": "2024-06-20T14:35:00.000Z"
}
```

---

## 🚀 Flujo de Desarrollo para Nuevas Funcionalidades

### **Agregar nueva categoría de producto:**
1. Crear producto en `StorageService._getDefaultProducts()`
2. CategoryChip se actualiza automáticamente
3. ProductCard mostrará el producto

### **Crear nueva métrica/estadística:**
1. Agregar cálculo en `Product` o `Sale` (getter)
2. Crear widget en `statistics_page.dart`
3. Usar `fl_chart` para visualizar

### **Integrar nueva API (ej: comprar stock):**
1. Crear método en nuevo service: `lib/services/api_service.dart`
2. Usar `http` package
3. Actualizar `Product.stock` después
4. Llamar `StorageService.saveProducts()`
5. Notificar `CartProvider.notifyListeners()`

### **Agregar validación de datos:**
1. Crear regla en `utils/helpers.dart`
2. Validar antes de `StorageService.saveProducts()`
3. Mostrar SnackBar con error en UI

---

## 📋 Checklist para Mantener Consistencia

- [ ] Todo modelo tiene `toJson()` y `fromJson()`
- [ ] Cambios en modelos → Actualizar serialización
- [ ] Cambios en datos → Llamar `StorageService.save*()`
- [ ] Cambios en estado del carrito → `CartProvider.notifyListeners()`
- [ ] Nuevas pantallas → Añadir a `home_page` o nav
- [ ] Nuevos widgets reutilizables → Carpeta `lib/widgets/`
- [ ] Código de utilidad → `lib/utils/`
- [ ] Tests para funciones críticas en `test/`

---

## 🔗 Referencias Rápidas

| Necesito... | Ir a... |
|------------|---------|
| Agregar producto | `ProductCard` en home_page.dart |
| Registrar venta | `StorageService.registerSale()` |
| Cambiar tema | `ThemeProvider` + `theme_provider.dart` |
| Mostrar gráfico | `statistics_page.dart` + `fl_chart` |
| Guardar datos | `StorageService.saveProducts()` |
| Persistir carrito | `CartProvider._saveCart()` |
| Exportar backup | `StorageService.exportData()` |

---

**Última actualización:** 2024-06-20  
**Versión:** 1.0.0  
**Estado:** ✅ Documentado y listo para desarrollo
