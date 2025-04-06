import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/section_delimiter.dart';

class PortsPage extends StatefulWidget {
  final String activeConfigurationPath; // Pass active config path

  const PortsPage({super.key, required this.activeConfigurationPath});

  @override
  PortsPageState createState() => PortsPageState();
}

class PortEntry {
  TextEditingController controller;
  FocusNode focusNode;
  bool isActive;
  String initialValue;
  String? error;

  PortEntry({
    required this.controller,
    required this.focusNode,
    required this.isActive,
    required this.initialValue,
    this.error,
  });
}

class PortsPageState extends State<PortsPage> {
  final List<PortEntry> _httpPorts = [];
  final List<PortEntry> _httpsPorts = [];

  @override
  void initState() {
    super.initState();
    _loadPortsFromConfiguration();
  }

  @override
  void dispose() {
    for (final entry in [..._httpPorts, ..._httpsPorts]) {
      entry.controller.dispose();
      entry.focusNode.dispose();
    }
    super.dispose();
  }

  void updatePorts() {
    _loadPortsFromConfiguration();
  }

  void _loadPortsFromConfiguration() {
    _httpPorts.clear();
    _httpsPorts.clear();

    if (widget.activeConfigurationPath.isEmpty) {
      _addDefaultHttpPort();
      _addDefaultHttpsPort();
      return;
    }

    File configFile = File(widget.activeConfigurationPath);
    if (configFile.existsSync()) {
      Map<String, dynamic> configData = jsonDecode(configFile.readAsStringSync());
      var httpList = configData["settings"]?["http_ports"] as List?;
      var httpsList = configData["settings"]?["https_ports"] as List?;

      if (httpList != null && httpList.isNotEmpty) {
        for (var item in httpList) {
          _httpPorts.add(_createPortEntry(item));
        }
      } else {
        _addDefaultHttpPort();
      }

      if (httpsList != null && httpsList.isNotEmpty) {
        for (var item in httpsList) {
          _httpsPorts.add(_createPortEntry(item));
        }
      } else {
        _addDefaultHttpsPort();
      }

      setState(() {});
    } else {
      _addDefaultHttpPort();
      _addDefaultHttpsPort();
    }
  }

  PortEntry _createPortEntry(dynamic item) {
    int port = item["port"] ?? 80;
    bool isActive = item["active"] ?? true;

    final entry = PortEntry(
      controller: TextEditingController(text: port.toString()),
      focusNode: FocusNode(),
      isActive: isActive,
      initialValue: port.toString(),
    );

    entry.focusNode.addListener(() {
      if (!entry.focusNode.hasFocus) {
        _validatePort(entry);
      } else {
        entry.initialValue = entry.controller.text;
      }
    });

    return entry;
  }

  void _validatePort(PortEntry currentEntry) {
    String text = currentEntry.controller.text.trim();
    int? port = int.tryParse(text);

    setState(() {
      // Validate current field
      if (port == null || port < 1 || port > 65535) {
        currentEntry.error = "Port must be between 1 and 65535";
      } else {
        final allEntries = [..._httpPorts, ..._httpsPorts];

        // Check for duplicates
        bool isDuplicate = allEntries.any((entry) {
          if (entry == currentEntry) return false;
          int? otherPort = int.tryParse(entry.controller.text.trim());
          return otherPort == port;
        });

        currentEntry.error = isDuplicate ? "This port is already used" : null;
      }

      // Revalidate all other fields (in case their duplicate is now resolved)
      final allEntries = [..._httpPorts, ..._httpsPorts];
      for (var entry in allEntries) {
        if (entry == currentEntry) continue;
        int? entryPort = int.tryParse(entry.controller.text.trim());

        if (entryPort == null || entryPort < 1 || entryPort > 65535) {
          entry.error = "Port must be between 1 and 65535";
        } else {
          bool isDuplicate = allEntries.any((other) {
            if (other == entry) return false;
            int? otherPort = int.tryParse(other.controller.text.trim());
            return otherPort == entryPort;
          });

          entry.error = isDuplicate ? "This port is already used" : null;
        }
      }

      // Save only if current field is OK
      if (currentEntry.error == null) {
        _saveAllPortsToConfiguration();
      }
    });
  }

  void _revalidateAllPorts() {
    final allEntries = [..._httpPorts, ..._httpsPorts];

    for (var entry in allEntries) {
      int? port = int.tryParse(entry.controller.text.trim());

      if (port == null || port < 1 || port > 65535) {
        entry.error = "Port must be between 1 and 65535";
      } else {
        bool isDuplicate = allEntries.any((other) {
          if (other == entry) return false;
          int? otherPort = int.tryParse(other.controller.text.trim());
          return otherPort == port;
        });

        entry.error = isDuplicate ? "This port is already used" : null;
      }
    }
  }

  void _addDefaultHttpPort() {
    _httpPorts.add(_createPortEntry({"port": 80, "active": true}));
  }

  void _addDefaultHttpsPort() {
    _httpsPorts.add(_createPortEntry({"port": 443, "active": true}));
  }

  void _addHttpPort() {
    final newEntry = _createPortEntry({"port": 80, "active": true});

    setState(() {
      _httpPorts.add(newEntry);
    });

    // Run validation once
    _validatePort(newEntry);
  }

  void _addHttpsPort() {
    final newEntry = _createPortEntry({"port": 443, "active": true});

    setState(() {
      _httpsPorts.add(newEntry);
    });

    _validatePort(newEntry);
  }

  void _removeHttpPort(int index) {
    setState(() {
      _httpPorts[index].controller.dispose();
      _httpPorts[index].focusNode.dispose();
      _httpPorts.removeAt(index);
      _saveAllPortsToConfiguration();
      _revalidateAllPorts();
    });
  }

  void _removeHttpsPort(int index) {
    setState(() {
      _httpsPorts[index].controller.dispose();
      _httpsPorts[index].focusNode.dispose();
      _httpsPorts.removeAt(index);
      _saveAllPortsToConfiguration();
      _revalidateAllPorts();
    });
  }

  void _saveAllPortsToConfiguration() {
    if (widget.activeConfigurationPath.isEmpty) return;
    File configFile = File(widget.activeConfigurationPath);
    if (!configFile.existsSync()) return;

    Map<String, dynamic> configData = jsonDecode(configFile.readAsStringSync());
    configData["settings"] ??= {};

    List<Map<String, dynamic>> httpList = _httpPorts
        .map((e) => {
      "port": int.tryParse(e.controller.text.trim()) ?? 80,
      "active": e.isActive,
    })
        .toList();

    List<Map<String, dynamic>> httpsList = _httpsPorts
        .map((e) => {
      "port": int.tryParse(e.controller.text.trim()) ?? 443,
      "active": e.isActive,
    })
        .toList();

    configData["settings"]["http_ports"] = httpList;
    configData["settings"]["https_ports"] = httpsList;

    configFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(configData));
  }

  List<Map<String, dynamic>> get httpPortsData => _httpPorts
      .map((e) => {
    "port": int.tryParse(e.controller.text.trim()) ?? 80,
    "active": e.isActive,
  })
      .toList();

  List<Map<String, dynamic>> get httpsPortsData => _httpsPorts
      .map((e) => {
    "port": int.tryParse(e.controller.text.trim()) ?? 443,
    "active": e.isActive,
  })
      .toList();

  Future<String?> _findVhostUsingPort(int portToCheck) async {
    if (widget.activeConfigurationPath.isEmpty) return null;

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return null;

    final data = jsonDecode(file.readAsStringSync());
    final vhosts = data["settings"]?["virtual_hosts"] as List<dynamic>?;

    if (vhosts == null) return null;

    for (final v in vhosts) {
      final vhostPort = int.tryParse(v["port"]);
      if (vhostPort == portToCheck) {
        return v["server_name"] ?? "(unnamed)";
      }
    }

    return null;
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
                              title: 'Ports',
                              helpText: 'Configure the Apache server ports.',
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'HTTP Ports',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildPortList(
                              _httpPorts,
                              _removeHttpPort,
                              _addHttpPort,
                              "Add HTTP Port",
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'HTTPS Ports',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildPortList(
                              _httpsPorts,
                              _removeHttpsPort,
                              _addHttpsPort,
                              "Add HTTPS Port",
                            ),
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

  Widget _buildPortList(
      List<PortEntry> entries,
      Function(int) onRemove,
      VoidCallback onAdd,
      String buttonLabel,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 168,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, color: Color(0xFFECEFF1)),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF78909C),
                  foregroundColor: const Color(0xFFECEFF1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 🔹 List of Ports (below)
        Column(
          children: List.generate(entries.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _buildPortField(entries[index]),
                  const SizedBox(width: 12),
                  Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        checkColor: WidgetStateProperty.all<Color>(Colors.white),
                        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF78909C);
                          }
                          return const Color(0xFFECEFF1);
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                        side: const BorderSide(color: Color(0xFF78909C), width: 1),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: entries[index].isActive,
                          onChanged: (val) {
                            setState(() {
                              entries[index].isActive = val ?? true;
                              _saveAllPortsToConfiguration();
                            });
                          },
                        ),
                        const Text("Active"),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final portText = entries[index].controller.text.trim();
                      final portValue = int.tryParse(portText);
                      final isHttp = onRemove == _removeHttpPort;

                      if (portValue == null) return;

                      final vhostUsing = await _findVhostUsingPort(portValue);
                      if (vhostUsing != null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Port $portValue is used by Virtual Host "$vhostUsing" and cannot be deleted.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      bool? confirmDelete = await showDialog(
                        // ignore: use_build_context_synchronously
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text(
                              'Delete ${isHttp ? "HTTP" : "HTTPS"} Port $portValue?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: const Text('Are you sure you want to delete this port entry?'),
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
                                  backgroundColor: Colors.red,
                                  foregroundColor: const Color(0xFFECEFF1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3.5),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text("Delete"),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmDelete == true) {
                        onRemove(index);
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPortField(PortEntry entry) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: entry.controller,
            focusNode: entry.focusNode,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: entry.error != null ? Colors.red : Colors.black,
                  width: 2,
                ),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              hintText: "Port",
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            cursorColor: Colors.black,
            onChanged: (_) => _validatePort(entry),
          ),
          if (entry.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
