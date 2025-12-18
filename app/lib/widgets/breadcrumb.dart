import 'package:flutter/material.dart';
import '../utils/colors.dart';

class Breadcrumb extends StatelessWidget {
  final String current;

  const Breadcrumb({
    super.key,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 4),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home, size: 32),
            color: AppColors.primary,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(16),
          ),
          const SizedBox(width: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              current,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}