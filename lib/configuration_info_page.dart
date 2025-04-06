import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'widgets/section_delimiter.dart';

class ConfigurationInfoPage extends StatefulWidget {
  final String activeConfigurationPath;

  const ConfigurationInfoPage({
    super.key,
    required this.activeConfigurationPath,
  });

  @override
  State<ConfigurationInfoPage> createState() => _ConfigurationInfoPageState();
}

class _ConfigurationInfoPageState extends State<ConfigurationInfoPage> {
  String? _configName;
  String? _srvrootValue;
  List<Map<String, dynamic>> _ports = [];
  List<Map<String, dynamic>> _vhostSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadConfigurationInfo();
  }

  void _loadConfigurationInfo() {
    _srvrootValue = null;
    _ports = [];
    _vhostSummaries = [];

    if (widget.activeConfigurationPath.trim().isEmpty) {
      return;
    }

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return;

    final json = jsonDecode(file.readAsStringSync());
    _configName = json['name'] ?? "(Unnamed)";
    final settings = json['settings'] ?? {};

    _srvrootValue = settings['srvroot'];

    for (final type in ['http_ports', 'https_ports']) {
      final protocol = type == 'http_ports' ? 'HTTP' : 'HTTPS';
      final ports = (settings[type] as List?) ?? [];
      for (final p in ports) {
        _ports.add({
          "protocol": protocol,
          "port": p["port"].toString(),
          "inactive": (p["active"] == false).toString(),
        });
      }
    }

    final vhosts = (settings['virtual_hosts'] as List?) ?? [];
    for (final v in vhosts) {
      _vhostSummaries.add({
        "port": v["port"],
        "serverName": v["server_name"],
        "documentRoot": v["document_root"],
        "aliases": v["aliases"] ?? [],
        "active": v["active"] != false,
      });
    }

    setState(() {});
  }

  Widget _buildPortList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ports", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (_ports.isEmpty)
          const Text("(No ports found in configuration)", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey))
        else
          ..._ports.map((portMap) {
            final isInactive = portMap["inactive"] == "true";
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      portMap["protocol"] ?? "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isInactive ? const Color(0xFFD17C00) : Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    portMap["port"] ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      color: isInactive ? const Color(0xFFD17C00) : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildVirtualHostList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Virtual Hosts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (_vhostSummaries.isEmpty)
          const Text("(No virtual hosts found in configuration)", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey))
        else
          ..._vhostSummaries.map((host) {
            final isInactive = host["active"] == false;
            final Color textColor = isInactive ? const Color(0xFFD17C00) : Colors.black;
            final List<Widget> rows = [];

            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "VirtualHost on port ${host["port"]}",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
            ));

            rows.add(_buildIndentedLabelValue("ServerName", host["serverName"] ?? "", indent: 1, color: textColor));
            rows.add(_buildIndentedLabelValue("DocumentRoot", host["documentRoot"] ?? "", indent: 1, color: textColor));

            final aliases = host["aliases"] as List? ?? [];
            for (int i = 0; i < aliases.length; i++) {
              final alias = aliases[i];
              rows.add(_buildIndentedLabel("Alias ${i + 1}", indent: 1, color: textColor));
              rows.add(_buildIndentedLabelValue("URL Path", alias["url"] ?? "", indent: 2, color: textColor));
              rows.add(_buildIndentedLabelValue("Directory", alias["dir"] ?? "", indent: 2, color: textColor));
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
            );
          }),
      ],
    );
  }

  Widget _buildIndentedLabel(String label, {required int indent, required Color color}) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, bottom: 2),
      child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildIndentedLabelValue(String label, String value, {required int indent, required Color color}) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 128 - ((indent - 1) * 20.0),
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
          Flexible(child: Text(value, style: TextStyle(fontSize: 14, color: color))),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    final bool isNotFound = value.trim().toLowerCase() == "(not found)";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontStyle: isNotFound ? FontStyle.italic : FontStyle.normal,
            color: isNotFound ? Colors.grey : Colors.black,
          ),
        ),
      ],
    );
  }

  Future<void> _exportConfiguration() async {
    if (widget.activeConfigurationPath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active configuration selected!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final configFile = File(widget.activeConfigurationPath);
    if (!configFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration file does not exist!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Read and extract name + id
    String proposedFileName = 'exported_config.json';

    try {
      final json = jsonDecode(configFile.readAsStringSync());
      final name = (json['name'] ?? 'exported_config').toString();
      final id = (json['id'] ?? '').toString();

      String safeName = name
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove forbidden characters
          .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
          .trim();

      proposedFileName = id.isNotEmpty
          ? '$safeName ($id).json'
          : '$safeName.json';
    } catch (_) {
      // Fall back to default name
    }

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Configuration As...',
      fileName: proposedFileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath == null) return;

    try {
      await configFile.copy(outputPath);

      if (!mounted) return; // ADD THIS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return; // ADD THIS
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importConfiguration() async {
    String? importPath = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Configuration',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    ).then((result) => result?.files.single.path);

    if (importPath == null) return;

    bool? confirmImport = await showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Import Configuration?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "This will overwrite the active configuration with the selected file. Do you want to proceed?",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF78909C),
                foregroundColor: const Color(0xFFECEFF1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: const Color(0xFFECEFF1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Import"),
            ),
          ],
        );
      },
    );

    if (confirmImport != true) return;

    try {
      if (widget.activeConfigurationPath.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active configuration selected!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await File(importPath).copy(widget.activeConfigurationPath);

      if (!mounted) return;

      (context.findAncestorStateOfType<MainPageState>())?.updateConfigurationNameFromFile(widget.activeConfigurationPath);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadConfigurationInfo(); // Safe to call — doesn't use context directly
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(selectionColor: Colors.yellow),
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
                            const SectionDelimiter(
                              title: "Configuration Info",
                              helpText: "Values from the active configuration file (JSON).",
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 205,
                                  child: ElevatedButton.icon(
                                    onPressed: _exportConfiguration,
                                    icon: const Icon(Icons.file_upload_outlined, color: Color(0xFFECEFF1)),
                                    label: const Text('Export Configuration'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF78909C),
                                      foregroundColor: const Color(0xFFECEFF1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 205,
                                  child: ElevatedButton.icon(
                                    onPressed: _importConfiguration,
                                    icon: const Icon(Icons.file_download_outlined, color: Color(0xFFECEFF1)),
                                    label: const Text('Import Configuration'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF78909C),
                                      foregroundColor: const Color(0xFFECEFF1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildLabelValue("Configuration Name", _configName ?? "(Not found)"),
                            const SizedBox(height: 16),
                            _buildLabelValue(
                              "Configuration Path",
                              (widget.activeConfigurationPath.trim().isEmpty ? "(Not found)" :
                              (Platform.isWindows
                                  ? widget.activeConfigurationPath.replaceAll('/', '\\')
                                  : widget.activeConfigurationPath)),
                            ),
                            const SizedBox(height: 16),
                            _buildLabelValue("SRVROOT", _srvrootValue ?? "(Not found)"),
                            const SizedBox(height: 16),
                            _buildPortList(),
                            const SizedBox(height: 16),
                            _buildVirtualHostList(),
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
}
