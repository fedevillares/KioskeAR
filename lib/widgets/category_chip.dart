import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final String? emoji;

  const CategoryChip({
    Key? key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.emoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = category == 'Todos'
        ? AppConstants.primaryColor
        : AppConstants.getCategoryColor(category);

    final icon = category == 'Todos'
        ? Icons.apps
        : AppConstants.getCategoryIcon(category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : context.colors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null && emoji!.isNotEmpty)
              Text(emoji!, style: const TextStyle(fontSize: 16))
            else
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
            const SizedBox(width: 6),
            Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : context.colors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}