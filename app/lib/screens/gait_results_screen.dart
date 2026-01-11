import 'package:flutter/material.dart';
import '../models/gait_data.dart';
import '../services/data_export_service.dart';
import '../services/service_locator.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
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
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final dataExportService = getIt<DataExportService>();
      final file = await dataExportService.exportGaitSession(widget.sessionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported to: ${file.path.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.logger.info('Gait data exported successfully: ${file.path}');
    } catch (e) {
      AppLogger.logger.severe('Failed to export gait data: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export data. Check logs for details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

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

                    // Export Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isExporting ? null : _exportData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isExporting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Export Data to JSON',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
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