import 'package:flutter/material.dart';
import '../utils/colors.dart';

class TestButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool completed;
  final VoidCallback onPressed;

  const TestButton({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.completed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? AppColors.success : AppColors.border,
          width: 4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completed)
                  const Icon(
                    Icons.check_circle,
                    size: 40,
                    color: AppColors.success,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}