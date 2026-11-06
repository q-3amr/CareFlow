import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final dynamic icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isSquare;

  const ActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isSquare ? _buildSquareLayout() : _buildHorizontalLayout(),
      ),
    );
  }

  Widget _buildSquareLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: icon is Widget
              ? icon
              : Icon(icon as IconData, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: icon is Widget
                ? icon
                : Icon(icon as IconData, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.grey.shade400, size: 16),
        ],
      ),
    );
  }
}
