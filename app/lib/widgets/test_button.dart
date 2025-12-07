import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';

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
            padding: EdgeInsets.all(AppConstants.buttonPadding),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 56,
                  color: AppColors.primary,
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppConstants.bodyFontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completed)
                  Icon(
                    Icons.check_circle,
                    size: 48,
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