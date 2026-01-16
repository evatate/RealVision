import 'package:flutter/material.dart';
import '../models/eye_tracking_data.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../widgets/breadcrumb.dart';

class EyeTrackingResultsScreen extends StatefulWidget {
  const EyeTrackingResultsScreen({super.key});

  @override
  State<EyeTrackingResultsScreen> createState() => _EyeTrackingResultsScreenState();
}

class _EyeTrackingResultsScreenState extends State<EyeTrackingResultsScreen> {
  late EyeTrackingSessionData _sessionData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is EyeTrackingSessionData) {
      _sessionData = args;
      AppLogger.logger.info('Results screen loaded with ${_sessionData.trials.length} trials');
      AppLogger.logger.info('Features: ${_sessionData.features.toJson()}');
    } else {
      // Fallback if no data provided
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Breadcrumb(current: 'Eye Tracking Results'),
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
                          Icons.visibility,
                          size: 32,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Eye Tracking Results',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Summary Card
                    _buildCard(
                      'Test Summary',
                      Column(
                        children: [
                          _buildSummaryRow('Total Trials', '${_sessionData.trials.length}'),
                          _buildSummaryRow('Fixation Trials', '${_sessionData.trials.where((t) => t.taskType == 'fixation').length}'),
                          _buildSummaryRow('Saccade Trials', '${_sessionData.trials.where((t) => t.taskType == 'prosaccade').length}'),
                          _buildSummaryRow('Pursuit Trials', '${_sessionData.trials.where((t) => t.taskType == 'pursuit').length}'),
                          _buildSummaryRow('Total Frames', '${_sessionData.trials.fold<int>(0, (sum, t) => sum + t.frames.length)}'),
                          _buildSummaryRow('Session ID', "[200m${_sessionData.sessionId.substring(0, 20)}..."),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Fixation Metrics
                    _buildCard(
                      'Fixation Stability',
                      Column(
                        children: [
                          _buildFeatureRow(
                            'Fixation Stability',
                            '${(_sessionData.features.fixationStability * 100).toStringAsFixed(1)}%',
                            'Overall stability during fixation (0-100%)',
                          ),
                          _buildFeatureRow(
                            'Max Fixation Duration',
                            '${_sessionData.features.fixationDuration.toStringAsFixed(2)} s',
                            'Longest continuous fixation period',
                          ),
                          _buildFeatureRow(
                            'Large Intrusive Saccades',
                            '${_sessionData.features.largeIntrusiveSaccades}',
                            'Unwanted large eye movements (>3.5% screen)',
                          ),
                          _buildFeatureRow(
                            'Square Wave Jerks',
                            '${_sessionData.features.squareWaveJerks}',
                            'Small back-and-forth saccades (<300ms)',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Saccade Metrics
                    _buildCard(
                      'Pro-Saccade Performance',
                      Column(
                        children: [
                          _buildFeatureRow(
                            'Saccade Accuracy',
                            '${(_sessionData.features.saccadeAccuracy * 100).toStringAsFixed(1)}%',
                            'Success rate reaching peripheral targets',
                          ),
                          _buildFeatureRow(
                            'Saccade Latency',
                            '${_sessionData.features.saccadeLatency.toStringAsFixed(0)} ms',
                            'Average reaction time to target appearance',
                          ),
                          _buildFeatureRow(
                            'Mean Saccades/Trial',
                            _sessionData.features.meanSaccadesPerTrial.toStringAsFixed(1),
                            'Average number of saccades per trial',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Pursuit Metrics
                    _buildCard(
                      'Smooth Pursuit Tracking',
                      Column(
                        children: [
                          _buildFeatureRow(
                            'Pursuit Gain',
                            _sessionData.features.pursuitGain.toStringAsFixed(2),
                            'Eye velocity / target velocity (ideal: 1.0)',
                          ),
                          _buildFeatureRow(
                            'Proportion Pursuing',
                            '${(_sessionData.features.proportionPursuing * 100).toStringAsFixed(1)}%',
                            'Time actively tracking the target',
                          ),
                          _buildFeatureRow(
                            'Catch-Up Saccades',
                            '${_sessionData.features.catchUpSaccades}',
                            'Corrective saccades when falling behind',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Overall Performance
                    _buildCard(
                      'Overall Performance',
                      Column(
                        children: [
                          _buildFeatureRow(
                            'Overall Accuracy',
                            '${(_sessionData.features.overallAccuracy * 100).toStringAsFixed(1)}%',
                            'Combined performance across all tasks',
                          ),
                          _buildFeatureRow(
                            'Task Completion Rate',
                            '${(_sessionData.features.taskCompletionRate * 100).toStringAsFixed(1)}%',
                            'Percentage of high-quality trials',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ...export button removed...

                    // Back to Home Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 2),
                          padding: const EdgeInsets.all(18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(fontSize: 20, color: AppColors.primary, fontWeight: FontWeight.w600),
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

  Widget _buildCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textMedium,
            ),
          ),
          label == 'Session ID'
              ? Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}