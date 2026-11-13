import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class StarRatingWidget extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double>? onRatingChanged;
  final double starSize;
  final bool isReadOnly;

  const StarRatingWidget({
    super.key,
    this.initialRating = 5.0,
    this.onRatingChanged,
    this.starSize = 24.0,
    this.isReadOnly = false,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating.clamp(0.0, 5.0);
  }

  @override
  void didUpdateWidget(StarRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRating != oldWidget.initialRating) {
      setState(() {
        _currentRating = widget.initialRating.clamp(0.0, 5.0);
      });
    }
  }

  void _onStarTapped(int starIndex) {
    if (widget.isReadOnly) return;
    final newRating = starIndex.toDouble();
    setState(() => _currentRating = newRating);
    widget.onRatingChanged?.call(newRating);
  }

  IconData _iconForStar(int starIndex) {
    if (_currentRating >= starIndex) {
      return Icons.star_rounded;
    } else if (_currentRating >= starIndex - 0.5) {
      return Icons.star_half_rounded;
    } else {
      return Icons.star_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unfilledColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final stars = List.generate(5, (i) {
      final starIndex = i + 1;
      final icon = _iconForStar(starIndex);
      final isFilled = icon != Icons.star_outline_rounded;

      final starIcon = Icon(
        icon,
        color: isFilled ? AppColors.starAmber : unfilledColor,
        size: widget.starSize,
      );

      if (widget.isReadOnly) return starIcon;

      return InkResponse(
        onTap: () => _onStarTapped(starIndex),
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: starIcon),
        ),
      );
    });

    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }
}
