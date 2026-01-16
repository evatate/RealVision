import 'package:flutter/material.dart';
import '../models/gait_data.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../widgets/breadcrumb.dart';

class GaitResultsScreen extends StatefulWidget {
  final GaitSessionData sessionData;

  const GaitResultsScreen({
    super.key,
    required this.sessionData,
  });

  @override
  State<GaitResultsScreen> createState() => _GaitResultsScreenState();
}

class _GaitResultsScreenState extends State<GaitResultsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Breadcrumb(current: 'Walking Test Results'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppConstants.buttonSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.directions_walk,
                          size: 32,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Walking Test Results',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.1 * 255).toInt()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Summary',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryRow('Duration', '${widget.sessionData.trials.first.duration.toStringAsFixed(1)} seconds'),
                          _buildSummaryRow('Steps Taken', '${widget.sessionData.trials.first.stepCount}'),
                          _buildSummaryRow('Data Frames', '${widget.sessionData.trials.first.frames.length}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Clinical Features
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.1 * 255).toInt()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical Features',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureRow('Cadence', '${widget.sessionData.features.cadence.toStringAsFixed(1)} steps/min', 'Steps per minute'),
                          _buildFeatureRow('Step Time', '${widget.sessionData.features.stepTime.toStringAsFixed(2)} s', 'Average time per step'),
                          _buildFeatureRow('Step Time Variability', '${(widget.sessionData.features.stepTimeVariability * 100).toStringAsFixed(1)}%', 'Coefficient of variation'),
                          _buildFeatureRow('Stride Length', widget.sessionData.features.strideLength.toStringAsFixed(1), 'Estimated normalized stride'),
                          _buildFeatureRow('Gait Regularity', '${(widget.sessionData.features.gaitRegularity * 100).toStringAsFixed(1)}%', 'Pattern consistency (0-100%)'),
                          _buildFeatureRow('Gait Symmetry', '${(widget.sessionData.features.gaitSymmetry * 100).toStringAsFixed(1)}%', 'Left-right balance (0-100%)'),
                          _buildFeatureRow('Acceleration Variability', widget.sessionData.features.accelerationVariability.toStringAsFixed(2), 'Movement smoothness'),
                          _buildFeatureRow('Gait Quality Score', '${(widget.sessionData.features.gaitQualityScore * 100).toStringAsFixed(1)}%', 'Overall assessment (0-100%)'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ...export button removed...

                    // Back to Home Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(fontSize: 18, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textMedium,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}