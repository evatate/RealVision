import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/smile_data.dart';
import '../services/data_export_service.dart';
import '../utils/colors.dart';
import '../utils/logger.dart';
import '../models/test_progress.dart';
import '../services/service_locator.dart';

class SmileResultsScreen extends StatefulWidget {
  final SmileSessionData sessionData;
  final String? exportPath;

  const SmileResultsScreen({
    Key? key,
    required this.sessionData,
    this.exportPath,
  }) : super(key: key);

  @override
  State<SmileResultsScreen> createState() => _SmileResultsScreenState();
}

class _SmileResultsScreenState extends State<SmileResultsScreen> {
  late DataExportService _exportService;

  @override
  void initState() {
    super.initState();
    _exportService = getIt<DataExportService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Smile Test Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Info
              _buildSessionInfo(),

              SizedBox(height: 24),

              // Feature Summary
              _buildFeatureSummary(),

              SizedBox(height: 24),

              // Trial Details
              _buildTrialDetails(),

              SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('Participant ID', widget.sessionData.participantId),
            _buildInfoRow('Session ID', widget.sessionData.sessionId),
            _buildInfoRow('Timestamp', widget.sessionData.timestamp.toString()),
            _buildInfoRow('Trials Completed', widget.sessionData.trials.length.toString()),
            _buildInfoRow('Total Frames', _calculateTotalFrames().toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSummary() {
    final features = widget.sessionData.features;
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 12),
            _buildFeatureRow('Smiling Duration', '${features.smilingDuration.toStringAsFixed(2)}s'),
            _buildFeatureRow('Proportion Smiling', features.proportionSmiling.toStringAsFixed(3)),
            _buildFeatureRow('Time to Smile', '${features.timeToSmile.toStringAsFixed(2)}s'),
            _buildFeatureRow('Mean Smile Index', features.meanSmileIndex.toStringAsFixed(3)),
            _buildFeatureRow('Max Smile Index', features.maxSmileIndex.toStringAsFixed(3)),
            _buildFeatureRow('Min Smile Index', features.minSmileIndex.toStringAsFixed(3)),
            _buildFeatureRow('Smile Index Std Dev', features.stdSmileIndex.toStringAsFixed(3)),
            _buildFeatureRow('Smile-Neutral Difference', features.smileNeutralDifference.toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialDetails() {
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trial Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            ...widget.sessionData.trials.map((trial) => _buildTrialRow(trial)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportData,
            icon: Icon(Icons.download),
            label: Text('Export Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.all(16),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _continueToNextTest,
            icon: Icon(Icons.arrow_forward),
            label: Text('Next Test'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textDark, fontSize: 12),
          ),
          SizedBox(height: 2),
          Container(
            width: double.infinity,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textDark, fontSize: 12),
          ),
          SizedBox(height: 2),
          Container(
            width: double.infinity,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialRow(SmileTrialData trial) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trial ${trial.trialNumber}',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            '${trial.frames.length} frames',
            style: TextStyle(color: AppColors.textDark, fontSize: 12),
          ),
        ],
      ),
    );
  }

  int _calculateTotalFrames() {
    return widget.sessionData.trials.fold(0, (sum, trial) => sum + trial.frames.length);
  }

  void _exportData() async {
    try {
      final file = await _exportService.exportSmileSession(widget.sessionData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported to: ${file.path.split('/').last}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      AppLogger.logger.severe('Failed to export data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _continueToNextTest() {
    Provider.of<TestProgress>(context, listen: false).markSmileCompleted();
    Navigator.of(context).pop();
  }
}