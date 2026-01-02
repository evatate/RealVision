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
        color: completed ? Colors.green[50] : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? Colors.green[400]! : AppColors.border,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: completed ? Colors.green[100] : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: completed ? Colors.green[700] : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completed)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[700],
                    size: 32,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}