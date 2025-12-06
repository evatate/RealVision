import 'package:flutter/material.dart';

class AudioInstruction extends StatelessWidget {
  final String text;
  final VoidCallback? onSpeak;

  const AudioInstruction({
    super.key,
    required this.text,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: onSpeak,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}