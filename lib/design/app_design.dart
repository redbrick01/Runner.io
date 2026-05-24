import 'package:flutter/material.dart';

import '../app_colors.dart';

class AppSpacing {
  static const page = EdgeInsets.fromLTRB(16, 8, 16, 24);
  static const card = EdgeInsets.all(16);
  static const cardLarge = EdgeInsets.all(20);
  static const gapTiny = SizedBox(height: 6);
  static const gapSmall = SizedBox(height: 10);
  static const gap = SizedBox(height: 14);
  static const gapLarge = SizedBox(height: 20);
}

class AppRadii {
  static const double control = 14;
  static const double card = 18;
  static const double heroCard = 28;
}

class AppTextStyles {
  static const sectionTitle = TextStyle(
    color: AppColors.text,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const label = TextStyle(
    color: AppColors.secondaryText,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const metric = TextStyle(
    color: AppColors.text,
    fontSize: 22,
    fontWeight: FontWeight.w900,
  );
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.margin = EdgeInsets.zero,
    this.color = AppColors.surface,
    this.radius = AppRadii.card,
    this.shadow = false,
    this.width = double.infinity,
    this.height,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final double radius;
  final bool shadow;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class AppSegmentOption<T> {
  const AppSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<AppSegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(4),
      radius: AppRadii.control,
      child: Row(
        children: options
            .map((option) {
              final selected = option.value == value;
              return Expanded(
                child: InkWell(
                  onTap: selected ? null : () => onChanged(option.value),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.secondaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppTextStyles.metric),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      margin: margin,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
