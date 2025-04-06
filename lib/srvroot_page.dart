import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/section_delimiter.dart';

class SrvRootPage extends StatefulWidget {
  final String activeConfigurationPath;
  final String activeServerLocation;

  const SrvRootPage({
    super.key,
    required this.activeConfigurationPath,
    required this.activeServerLocation, // NEW
  });

  @override
  State<SrvRootPage> createState() => SrvRootPageState();
}

class SrvRootPageState extends State<SrvRootPage> {
  final TextEditingController _srvRootController = TextEditingController();
  String _initialSrvRoot = "";
  String? _error;
  late String _defaultSrvRoot;

  @override
  void initState() {
    super.initState();
    _computeDefaultSrvRoot();
    _loadSrvRootFromConfig();
  }

  @override
  void dispose() {
    _srvRootController.dispose();
    super.dispose();
  }

  void _computeDefaultSrvRoot() {
    final normalizedPath = widget.activeServerLocation.replaceAll(r'\', '/');
    _defaultSrvRoot = '$normalizedPath/Apache24';
  }

  void updateSrvRoot() {
    _computeDefaultSrvRoot(); // Recalculate default just in case
    _loadSrvRootFromConfig(); // Re-read from updated config
  }

  void _loadSrvRootFromConfig() {
    if (widget.activeConfigurationPath.isEmpty) return;

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return;

    final content = jsonDecode(file.readAsStringSync());
    final srvroot = content["settings"]?["srvroot"] ?? "";

    setState(() {
      _srvRootController.text = srvroot;
      _initialSrvRoot = srvroot;
    });
  }

  void _saveSrvRootToConfig(String value) {
    if (widget.activeConfigurationPath.isEmpty) return;

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return;

    final json = jsonDecode(file.readAsStringSync());
    json["settings"] ??= {};
    json["settings"]["srvroot"] = value.trim();

    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
  }

  void _onFieldFocusLost() {
    var value = _srvRootController.text.trim();
    if (value.isEmpty) {
      setState(() => _error = null);
      _srvRootController.text = _defaultSrvRoot;
      _saveSrvRootToConfig(_defaultSrvRoot);
      _initialSrvRoot = _defaultSrvRoot;
    } else {
      if (value.contains(r'\')) {
        value = value.replaceAll(r'\', '/');
        _srvRootController.text = value;
      }
      setState(() => _error = null);
      if (value != _initialSrvRoot) {
        _saveSrvRootToConfig(value);
        _initialSrvRoot = value;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Colors.yellow,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: 640,
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionDelimiter(
                              title: "SRVROOT",
                              helpText: "Define the Apache SRVROOT (typically the path until Apache24).",
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Define SRVROOT",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildSrvRootField(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSrvRootField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _onFieldFocusLost();
          },
          child: TextFormField(
            controller: _srvRootController,
            decoration: InputDecoration(
              isDense: true,
              hintText: _defaultSrvRoot,
              hintStyle: const TextStyle(color: Colors.grey),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _error != null ? Colors.red : Colors.black,
                  width: 2,
                ),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
            cursorColor: Colors.black,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
