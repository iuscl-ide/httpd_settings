import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

class ConfigContentPanel extends StatefulWidget {
  final String? currentPage; // e.g. 'SRVROOT', 'Ports', etc.

  const ConfigContentPanel({
    super.key,
    required this.currentPage,
  });

  @override
  State<ConfigContentPanel> createState() => ConfigContentPanelState();
}

class ConfigContentPanelState extends State<ConfigContentPanel> {
  final List<ConfigSection> _sections = [];
  final ScrollController _scrollController = ScrollController();

  void updateContent(List<ConfigSection> sections) {
    setState(() {
      _sections
        ..clear()
        ..addAll(sections);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<ConfigSection> sectionsToShow = [];

    if (widget.currentPage == 'SRVROOT') {
      sectionsToShow = _sections.where((s) => s.title.contains('SRVROOT')).toList();
    } else if (widget.currentPage == 'Ports') {
      sectionsToShow = _sections.where((s) => s.title.contains('Ports')).toList();
    } else if (widget.currentPage == 'VirtualHosts') {
      sectionsToShow = _sections.where((s) => s.title.contains('Virtual Hosts')).toList();
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Colors.yellow,
        ),
      ),
      child: Container(
        color: const Color(0xFFFFF8DC),
        padding: const EdgeInsets.all(12),
        child: sectionsToShow.isNotEmpty
            ? Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
              child: SelectableText.rich(
                TextSpan(
                  children: sectionsToShow.expand((section) {
                    return [
                      TextSpan(
                        text: '${section.title}\n',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Consolas',
                          color: Colors.black,
                        ),
                      ),
                      const TextSpan(text: '\n'),
                      ...section.before.map((line) => TextSpan(
                        text: '$line\n',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Consolas',
                        ),
                      )),
                      ...section.highlight.map((tuple) {
                        final text = tuple.item1;
                        final isInactive = tuple.item2;
                        return TextSpan(
                          text: '$text\n',
                          style: TextStyle(
                            color: isInactive ? const Color(0xFFD17C00) : Colors.black,
                            fontFamily: 'Consolas',
                          ),
                        );
                      }),
                      ...section.after.map((line) => TextSpan(
                        text: '$line\n',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Consolas',
                        ),
                      )),
                      const TextSpan(text: '\n\n'),
                    ];
                  }).toList(),
                ),
              ),
            ),
          )
            : const Text(
          'Displayed only for a parameter page, and only after a configuration read from (or write to) the Apache server',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class ConfigSection {
  final String title;
  final List<String> before;
  final List<Tuple2<String, bool>> highlight;
  final List<String> after;

  ConfigSection({
    required this.title,
    required this.before,
    required this.highlight,
    required this.after,
  });
}
