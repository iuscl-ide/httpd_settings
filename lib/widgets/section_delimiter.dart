import 'package:flutter/material.dart';

class SectionDelimiter extends StatefulWidget {
  final String title;
  final String helpText;

  const SectionDelimiter({
    super.key,
    required this.title,
    required this.helpText,
  });

  @override
  SectionDelimiterState createState() => SectionDelimiterState();
}

class SectionDelimiterState extends State<SectionDelimiter> {
  bool _isHelpVisible = false;

  void _toggleHelp() {
    setState(() {
      _isHelpVisible = !_isHelpVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header band
        Container(
          color: const Color(0xFFECEFF1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), // Consistent padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _toggleHelp,
                icon: const Icon(Icons.help_outline),
                tooltip: 'Toggle Help',
                iconSize: 18, // Smaller icon size
              ),
            ],
          ),
        ),
        // Help panel
        if (_isHelpVisible)
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.helpText,
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }
}
