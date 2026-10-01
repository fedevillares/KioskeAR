import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Contenedor con efecto "liquid glass": blur de fondo, relleno translúcido,
/// borde sutil brillante y sombra suave. Se adapta automáticamente a modo
/// claro/oscuro usando el Brightness del Theme actual.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const GlassContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = AppConstants.glassBlur,
    this.width,
    this.height,
    this.gradient,
    this.color,
    this.boxShadow,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = color ?? (isDark ? AppConstants.glassFillDark : AppConstants.glassFillLight);
    final borderColor = isDark ? AppConstants.glassBorderDark : AppConstants.glassBorderLight;
    final shadowColor = isDark ? AppConstants.glassShadowDark : AppConstants.glassShadowLight;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? fill : null,
              borderRadius: borderRadius,
              border: border ?? Border.all(color: borderColor, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fondo degradado base usado en todas las pantallas, coherente con el
/// modo claro/oscuro actual.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? AppConstants.backgroundGradientDark : AppConstants.backgroundGradientLight,
        ),
      ),
      child: child,
    );
  }
}
