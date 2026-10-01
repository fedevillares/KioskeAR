import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'glass_container.dart';

/// Tarjeta de producto para la grilla de Inicio. Pensada para venta rápida
/// en el mostrador: una sola acción primaria (agregar al carrito) en vez de
/// múltiples botones compitiendo por la atención. El ajuste fino de stock
/// (+/-) vive en Inventario, donde ya existe un flujo de edición dedicado.
class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final Function(int) onStockChange;
  final VoidCallback? onAddToCart;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onTap,
    required this.onStockChange,
    this.onAddToCart,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;

  Color _getStatusColor() {
    if (widget.product.isOutOfStock) return AppConstants.errorColor;
    if (widget.product.isLowStock) return AppConstants.warningColor;
    return AppConstants.successColor;
  }

  @override
  Widget build(BuildContext context) {
    final stockPercentage = Helpers.getStockPercentage(widget.product.stock, widget.product.minStock);
    final statusColor = _getStatusColor();
    final canAddToCart = widget.onAddToCart != null && widget.product.stock > 0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          blur: 10,
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja lateral de acento: comunica el estado de stock sin
                // necesitar un borde grueso alrededor de toda la tarjeta.
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppConstants.radiusMedium),
                      bottomLeft: Radius.circular(AppConstants.radiusMedium),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'product_image_${widget.product.id}',
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppConstants.getCategoryColor(widget.product.category).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                                  child: widget.product.imagePath != null && widget.product.imagePath!.isNotEmpty
                                      ? Image.file(
                                          File(widget.product.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              AppConstants.getCategoryIcon(widget.product.category),
                                              size: 32,
                                              color: AppConstants.getCategoryColor(widget.product.category),
                                            );
                                          },
                                        )
                                      : Icon(
                                          AppConstants.getCategoryIcon(widget.product.category),
                                          size: 32,
                                          color: AppConstants.getCategoryColor(widget.product.category),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.product.name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        Helpers.formatPrice(widget.product.price),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          widget.product.isOutOfStock ? 'Agotado' : '${widget.product.stock} u.',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(AppConstants.getCategoryIcon(widget.product.category),
                                          size: 12, color: context.colors.textTertiary),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.product.category,
                                        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _AddToCartButton(
                              enabled: canAddToCart,
                              statusColor: statusColor,
                              onTap: widget.onAddToCart,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(begin: 0, end: stockPercentage / 100),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: context.colors.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 5,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular único de acción primaria. El ajuste fino de stock (+/-)
/// se hace desde Inventario; acá la tarea más frecuente en venta es una
/// sola: sumar el producto al carrito.
class _AddToCartButton extends StatelessWidget {
  final bool enabled;
  final Color statusColor;
  final VoidCallback? onTap;

  const _AddToCartButton({required this.enabled, required this.statusColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppConstants.primaryColor : context.colors.divider,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.add_shopping_cart_rounded,
            size: 20,
            color: enabled ? Colors.white : context.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
