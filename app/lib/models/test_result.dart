class TestResult {
  final String testType;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final double? confidence;
  
  TestResult({
    required this.testType,
    required this.timestamp,
    required this.data,
    this.confidence,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'testType': testType,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'confidence': confidence,
    };
  }
  
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testType: json['testType'],
      timestamp: DateTime.parse(json['timestamp']),
      data: json['data'],
      confidence: json['confidence'],
    );
  }
}