class SpeechSegment {
  final String text;
  final Duration start;
  final Duration end;

  SpeechSegment({
    required this.text,
    required this.start,
    required this.end,
  });
}

class ChaTranscriptBuilder {
  static String build({
    required List<SpeechSegment> segments,
    required Duration totalDuration,
    String participant = 'PAR',
    String language = 'eng',
    String study = 'speech_test',
  }) {
    // Add CHA user prompt tag if prompt is detected
    const String kSpeechPrompt = 'Please describe everything you see in the picture and explain what is happening, what people are doing, and how the scene fits together. Continue speaking until I tell you to stop.';
    const String kChaPromptTag = 'CHA-PROMPT: ';
    final buffer = StringBuffer();

    buffer.writeln('@Begin');
    buffer.writeln('@Participants:\t$participant Participant');
    buffer.writeln('@ID:\t$language|$study|$participant|||');
    buffer.writeln('@Media:\tspeech_recording, audio');
    buffer.writeln();

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];

      // If the prompt is present, add the CHA tag
      if (seg.text.trim() == kSpeechPrompt) {
        buffer.writeln('$kChaPromptTag${seg.text}');
      } else {
        buffer.writeln('*$participant:\t${_normalize(seg.text)} .');
      }

      // Pause before next segment
      if (i < segments.length - 1) {
        final next = segments[i + 1];
        final pause =
            next.start.inMilliseconds - seg.end.inMilliseconds;

        if (pause > 300) {
          buffer.writeln(
            '%pau:\t${(pause / 1000).toStringAsFixed(2)}',
          );
        }
      }
    }

    buffer.writeln();
    buffer.writeln('@End');

    return buffer.toString();
  }

  static String _normalize(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();
  }
}