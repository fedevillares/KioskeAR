import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/permission.dart';
import '../models/product.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../screens/barcode_scanner_page.dart';
import 'glass_container.dart';

class AddProductDialog extends StatefulWidget {
  final Product? product;
  final Function(Product) onSave;
  final String? initialBarcode;
  final List<Product>? existingProducts;
  final List<String>? categories;
  final Map<String, String>? categoryEmojis;

  const AddProductDialog({
    Key? key,
    this.product,
    required this.onSave,
    this.initialBarcode,
    this.existingProducts,
    this.categories,
    this.categoryEmojis,
  }) : super(key: key);

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _barcodeController;
  late TextEditingController _discountController;
  late String _selectedCategory;
  String? _imagePath;
  bool _imageLoading = false;
  String? _barcodeError;
  bool _offerEnabled = false;
  DateTime? _discountExpiresAt;
  DateTime? _expirationDate;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(text: _formatNumberForEdit(product?.price));
    _costPriceController = TextEditingController(
      text: (product?.costPrice ?? 0) > 0 ? _formatNumberForEdit(product?.costPrice) : '',
    );
    _stockController = TextEditingController(text: product?.stock.toString() ?? '');
    _minStockController = TextEditingController(text: product?.minStock.toString() ?? '5');
    _barcodeController = TextEditingController(text: product?.barcode ?? widget.initialBarcode ?? '');

    final savedDiscount = product?.discountPercent;
    _offerEnabled = savedDiscount != null && savedDiscount > 0;
    _discountController = TextEditingController(
      text: _offerEnabled ? _formatNumberForEdit(savedDiscount) : '',
    );
    _discountExpiresAt = product?.discountExpiresAt;
    _expirationDate = product?.expirationDate;

    // Si la categoría guardada ya no existe en la lista actual (datos viejos,
    // categoría eliminada, o el valor "Todos" guardado por error), el
    // DropdownButtonFormField crashea porque su `value` no matchea ningún
    // `item`. Por eso validamos contra la lista real de categorías válidas,
    // que puede incluir categorías propias del kiosco además de las base.
    final validCategories = _availableCategories.skip(1).toSet();
    final savedCategory = product?.category;
    _selectedCategory = (savedCategory != null && validCategories.contains(savedCategory))
        ? savedCategory
        : _availableCategories[1];

    _imagePath = product?.imagePath;
  }

  /// Categorías a mostrar en el dropdown: las del kiosco (base + propias)
  /// si vienen del padre, o solo las base como respaldo.
  List<String> get _availableCategories =>
      (widget.categories != null && widget.categories!.isNotEmpty)
          ? widget.categories!
          : AppConstants.categories;

  /// Evita mostrar "1500.0" al editar: si no tiene centavos, los oculta.
  String _formatNumberForEdit(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _imageLoading = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppConstants.primaryColor),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppConstants.primaryColor),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppConstants.errorColor),
                  title: const Text('Eliminar foto'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imagePath = null;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Busca si el código de barras ya pertenece a otro producto.
  /// Devuelve el producto encontrado, o null si no hay conflicto.
  Product? _findDuplicate(String code) {
    if (code.isEmpty) return null;
    final list = widget.existingProducts;
    if (list == null) return null;
    for (final p in list) {
      if (p.barcode == code && p.id != widget.product?.id) return p;
    }
    return null;
  }

  void _checkBarcodeDuplicate(String code) {
    final existing = _findDuplicate(code.trim());
    setState(() {
      _barcodeError = existing != null ? 'Ya pertenece a "${existing.name}"' : null;
    });
  }

  Future<void> _scanBarcodeForField() async {
    // Sacamos el foco ANTES de navegar: si el campo de código de barras
    // (u otro campo del form) queda enfocado mientras la cámara está
    // abierta, Flutter reabre el teclado apenas la pantalla de escaneo
    // hace pop, tapando media pantalla justo cuando el usuario quiere
    // ver el resultado. unfocus() evita que quede ningún campo "pidiendo"
    // el teclado de vuelta.
    FocusScope.of(context).unfocus();

    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );

    if (code == null || code.isEmpty || !mounted) return;

    // Igualmente al volver: nos asegura que, aunque algún widget intente
    // recuperar foco automáticamente al reconstruirse, lo cancelemos antes
    // del próximo frame.
    FocusScope.of(context).unfocus();

    setState(() {
      _barcodeController.text = code;
    });
    _checkBarcodeDuplicate(code);

    if (_barcodeError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠ Ese código ya pertenece a "${_findDuplicate(code)?.name}"'),
          backgroundColor: AppConstants.warningColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Código escaneado correctamente'),
          backgroundColor: AppConstants.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  double _roundTo2(double value) => (value * 100).round() / 100;

  /// Valida el % de descuento solo si el modo oferta está activo.
  /// No usamos `validator` clásico porque el campo entero se oculta/muestra
  /// según `_offerEnabled`, y Form.validate() igual recorrería un campo
  /// invisible si lo dejáramos siempre montado con validator.
  String? _validateDiscount() {
    if (!_offerEnabled) return null;
    final text = _discountController.text.trim();
    if (text.isEmpty) return 'Ingresá el % de descuento';
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return 'Porcentaje inválido';
    if (value <= 0 || value > 90) return 'Debe ser entre 1% y 90%';
    return null;
  }

  Future<void> _pickDiscountExpiry() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _discountExpiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Vencimiento de la oferta',
      cancelText: 'Sin vencimiento',
      confirmText: 'Confirmar',
    );
    if (!mounted) return;
    setState(() {
      _discountExpiresAt = picked;
    });
  }

  Future<void> _pickExpirationDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Fecha de vencimiento',
      cancelText: 'Sin vencimiento',
      confirmText: 'Confirmar',
    );
    if (!mounted) return;
    setState(() {
      _expirationDate = picked;
    });
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final barcode = _barcodeController.text.trim();
    if (_findDuplicate(barcode) != null) {
      setState(() => _barcodeError = 'Ya pertenece a "${_findDuplicate(barcode)?.name}"');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠ Ese código de barras ya está en uso por otro producto'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    final discountValidation = _validateDiscount();
    if (discountValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠ $discountValidation'), backgroundColor: AppConstants.errorColor),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    final costPriceText = _costPriceController.text.trim();
    final costPrice = costPriceText.isEmpty ? 0.0 : double.tryParse(costPriceText);
    final stock = int.tryParse(_stockController.text.trim());
    final minStock = int.tryParse(_minStockController.text.trim());

    if (price == null || stock == null || minStock == null || costPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisá los valores numéricos, hay alguno inválido')),
      );
      return;
    }

    final discountPercent = _offerEnabled
        ? double.tryParse(_discountController.text.trim().replaceAll(',', '.'))
        : null;

    final product = Product(
      id: widget.product?.id ?? Helpers.generateId(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      stock: stock,
      price: _roundTo2(price),
      costPrice: _roundTo2(costPrice),
      minStock: minStock,
      barcode: barcode.isEmpty ? null : barcode,
      imagePath: _imagePath,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      lastUpdated: DateTime.now(),
      discountPercent: _offerEnabled ? discountPercent : null,
      discountExpiresAt: _offerEnabled ? _discountExpiresAt : null,
      expirationDate: _expirationDate,
    );

    widget.onSave(product);
    Navigator.pop(context);
  }

  Widget _buildImagePicker() {
    const placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 50, color: AppConstants.primaryColor),
        SizedBox(height: 8),
        Text('Agregar foto', style: TextStyle(color: AppConstants.primaryColor)),
      ],
    );

    Widget content = placeholder;
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(_imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    if (_imageLoading) {
      content = const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryColor),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _imageLoading ? null : _showImageOptions,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3), width: 2),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isEditing ? Icons.edit_outlined : Icons.add_shopping_cart,
            color: AppConstants.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar producto' : 'Nuevo producto',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                isEditing
                    ? 'Actualizá los datos y guardá los cambios'
                    : 'Completá los datos para agregarlo al inventario',
                style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'Cerrar',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.withOpacity(0.08),
            shape: const CircleBorder(),
          ),
        ),
      ],
    );
  }

  /// Mini-encabezado de sección, para que el formulario se lea como bloques
  /// con sentido (identidad, precio/stock, identificación, oferta) en vez de
  /// una lista plana de campos sin agrupar.
  Widget _buildSectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppConstants.primaryColor.withOpacity(0.8)),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppConstants.primaryColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Emoji elegido por el usuario para esta categoría, si tiene uno
  /// asignado (categorías personalizadas pueden tenerlo); si no, null
  /// y se cae al ícono Material genérico.
  String? _emojiFor(String category) => widget.categoryEmojis?[category];

  Widget _buildCategoryDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedEmoji = _emojiFor(_selectedCategory);
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      dropdownColor: isDark ? const Color(0xFF221F33) : Colors.white,
      decoration: InputDecoration(
        labelText: 'Categoría *',
        prefixIcon: selectedEmoji != null
            ? Center(child: Text(selectedEmoji, style: const TextStyle(fontSize: 18)))
            : Icon(AppConstants.getCategoryIcon(_selectedCategory)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _availableCategories.skip(1).map((cat) {
        final emoji = _emojiFor(cat);
        return DropdownMenuItem(
          value: cat,
          child: Row(
            children: [
              if (emoji != null)
                Text(emoji, style: const TextStyle(fontSize: 18))
              else
                Icon(AppConstants.getCategoryIcon(cat), size: 20, color: AppConstants.getCategoryColor(cat)),
              const SizedBox(width: 8),
              Text(cat, style: TextStyle(color: context.colors.textPrimary)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildOfferSection() {
    final canApplyDiscounts = context.read<SessionProvider>().hasPermission(Permission.aplicarDescuentos);
    final price = double.tryParse(_priceController.text.trim());
    final discount = double.tryParse(_discountController.text.trim().replaceAll(',', '.'));
    final showPreview = _offerEnabled && price != null && discount != null && discount > 0 && discount <= 90;
    final discountedPrice = showPreview ? _roundTo2(price! * (1 - discount! / 100)) : null;

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.warningColor.withOpacity(_offerEnabled ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.warningColor.withOpacity(_offerEnabled ? 0.4 : 0.15),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _offerEnabled,
            activeColor: AppConstants.warningColor,
            title: const Row(
              children: [
                Icon(Icons.local_offer, size: 20, color: AppConstants.warningColor),
                SizedBox(width: 8),
                Text('Modo oferta / descuento', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            subtitle: Text(
              canApplyDiscounts
                  ? 'Mostrá un precio rebajado por tiempo limitado o indefinido'
                  : 'No tenés permiso para aplicar descuentos. Pedíselo a un administrador.',
            ),
            onChanged: !canApplyDiscounts
                ? null
                : (value) {
                    setState(() {
                      _offerEnabled = value;
                      if (!value) {
                        _discountController.clear();
                        _discountExpiresAt = null;
                      }
                    });
                  },
          ),
          if (_offerEnabled) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    decoration: InputDecoration(
                      labelText: '% de descuento *',
                      suffixText: '%',
                      prefixIcon: const Icon(Icons.percent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDiscountExpiry,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Vence (opcional)',
                        prefixIcon: const Icon(Icons.event_busy),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                      ),
                      child: Text(
                        _discountExpiresAt != null
                            ? Helpers.formatDate(_discountExpiresAt!)
                            : 'Sin vencimiento',
                        style: TextStyle(
                          color: _discountExpiresAt != null ? null : context.colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_discountExpiresAt != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _discountExpiresAt = null),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Quitar vencimiento'),
                  style: TextButton.styleFrom(foregroundColor: context.colors.textSecondary),
                ),
              ),
            if (showPreview)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 2),
                child: Row(
                  children: [
                    Text(
                      Helpers.formatPrice(price!),
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: context.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Helpers.formatPrice(discountedPrice!),
                      style: const TextStyle(
                        color: AppConstants.warningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.warningColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${discount!.toStringAsFixed(discount == discount.roundToDouble() ? 0 : 1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(padding: EdgeInsets.only(bottom: 10)),
          ],
        ],
      ),
    );
  }

  Widget _buildExpirationSection() {
    final hasDate = _expirationDate != null;
    final days = hasDate
        ? DateTime(_expirationDate!.year, _expirationDate!.month, _expirationDate!.day)
            .difference(DateTime.now().subtract(const Duration(hours: 12)))
            .inDays
        : null;
    final isExpired = days != null && days < 0;
    final isSoon = days != null && !isExpired && days <= 7;
    final accentColor = isExpired
        ? AppConstants.errorColor
        : isSoon
            ? AppConstants.warningColor
            : AppConstants.successColor;

    return Container(
      decoration: BoxDecoration(
        color: accentColor.withOpacity(hasDate ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(hasDate ? 0.4 : 0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.event, size: 20, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: _pickExpirationDate,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vencimiento (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    hasDate
                        ? '${Helpers.formatDate(_expirationDate!)}'
                            '${isExpired ? ' · Vencido' : isSoon ? ' · Vence en $days días' : ''}'
                        : 'Tocá para elegir una fecha',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasDate ? accentColor : context.colors.textSecondary,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasDate)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _expirationDate = null),
              color: context.colors.textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _handleSave,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEditing ? 'Guardar' : 'Agregar'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screenSize.height * 0.88,
        ),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          blur: 26,
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isEditing),
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.withOpacity(0.15), height: 1),
                    const SizedBox(height: 20),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Información básica', Icons.badge_outlined),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: const Icon(Icons.inventory_2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: Helpers.validateProductName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Precio y costo', Icons.attach_money),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              labelText: 'Precio *',
                              prefixText: '\$ ',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            validator: Helpers.validatePrice,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            decoration: InputDecoration(
                              labelText: 'Costo',
                              prefixText: '\$ ',
                              prefixIcon: const Icon(Icons.shopping_bag),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            validator: Helpers.validateCostPrice,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Stock', Icons.inventory_2_outlined),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            decoration: InputDecoration(
                              labelText: 'Stock *',
                              prefixIcon: const Icon(Icons.inventory),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: Helpers.validateStock,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minStockController,
                            decoration: InputDecoration(
                              labelText: 'Stock mín',
                              prefixIcon: const Icon(Icons.warning_amber),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: Helpers.validateStock,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Identificación', Icons.qr_code_2),
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Código de barras',
                        prefixIcon: const Icon(Icons.qr_code),
                        errorText: _barcodeError,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppConstants.primaryColor),
                          tooltip: 'Escanear código',
                          onPressed: _scanBarcodeForField,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _checkBarcodeDuplicate,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSave(),
                    ),
                    const SizedBox(height: 24),
                    _buildOfferSection(),
                    const SizedBox(height: 16),
                    _buildExpirationSection(),
                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.withOpacity(0.15), height: 1),
                    const SizedBox(height: 16),
                    _buildActionButtons(isEditing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
