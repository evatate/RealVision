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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? AppColors.success : AppColors.border,
          width: 3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: AppColors.primary,
                ),
                SizedBox(width: 16),
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
                      SizedBox(height: 2),
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
                    size: 36,
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