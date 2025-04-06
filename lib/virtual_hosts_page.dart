import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/section_delimiter.dart';

class _VirtualHostEntry {
  String port;
  bool isActive;
  final TextEditingController serverNameController;
  final TextEditingController documentRootController;
  final FocusNode serverNameFocusNode;
  final FocusNode documentRootFocusNode;
  final List<_AliasEntry> aliases;

  String? serverNameError;
  String? documentRootError;

  _VirtualHostEntry({
    required this.port,
    this.isActive = true,
    required String serverName,
    required String documentRoot,
    List<_AliasEntry>? aliases,
  })  : serverNameController = TextEditingController(text: serverName),
        documentRootController = TextEditingController(text: documentRoot),
        serverNameFocusNode = FocusNode(),
        documentRootFocusNode = FocusNode(),
        aliases = aliases ?? [];
}

class _AliasEntry {
  final TextEditingController urlController;
  final TextEditingController dirController;
  final FocusNode urlFocusNode;
  final FocusNode dirFocusNode;

  String? urlError;
  String? dirError;

  _AliasEntry({String url = '', String dir = ''})
      : urlController = TextEditingController(text: url),
        dirController = TextEditingController(text: dir),
        urlFocusNode = FocusNode(),
        dirFocusNode = FocusNode();
}

class VirtualHostsPage extends StatefulWidget {
  final String activeConfigurationPath;

  const VirtualHostsPage({super.key, required this.activeConfigurationPath});

  @override
  State<VirtualHostsPage> createState() => VirtualHostsPageState();
}

class VirtualHostsPageState extends State<VirtualHostsPage> {
  final List<Map<String, dynamic>> _availablePorts = [];
  final List<_VirtualHostEntry> _vhosts = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePorts();
    _loadVirtualHostsFromConfig();
  }

  void updateVirtualHosts() {
    _loadAvailablePorts();
    _loadVirtualHostsFromConfig();
  }

  void _loadAvailablePorts() {
    _availablePorts.clear();
    if (widget.activeConfigurationPath.isEmpty) return;

    File configFile = File(widget.activeConfigurationPath);
    if (!configFile.existsSync()) return;

    Map<String, dynamic> configData = jsonDecode(configFile.readAsStringSync());
    var httpList = configData["settings"]?["http_ports"] as List?;
    var httpsList = configData["settings"]?["https_ports"] as List?;

    if (httpList != null) {
      _availablePorts.addAll(httpList.where((e) => e["active"] == true).cast<Map<String, dynamic>>());
    }
    if (httpsList != null) {
      _availablePorts.addAll(httpsList.where((e) => e["active"] == true).cast<Map<String, dynamic>>());
    }
  }

  void _loadVirtualHostsFromConfig() {
    _vhosts.clear();

    if (widget.activeConfigurationPath.isEmpty) return;

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return;

    final configData = jsonDecode(file.readAsStringSync());
    final settings = configData["settings"] ?? {};
    final vhostList = settings["virtual_hosts"] as List<dynamic>?;

    if (vhostList == null || vhostList.isEmpty) return;

    for (final v in vhostList) {
      final portValue = v["port"];

      final entry = _VirtualHostEntry(
        port: portValue is int ? portValue.toString() : (portValue ?? ""),
        isActive: v["active"] ?? true,
        serverName: v["server_name"] ?? "localhost",
        documentRoot: v["document_root"] ?? "",
        aliases: [],
      );

      for (final alias in (v["aliases"] ?? []) as List<dynamic>) {
        final aliasEntry = _AliasEntry(
          url: alias["url"] ?? "",
          dir: alias["dir"] ?? "",
        );

        aliasEntry.urlFocusNode.addListener(() {
          if (!aliasEntry.urlFocusNode.hasFocus) {
            final text = aliasEntry.urlController.text.trim();
            if (text.isNotEmpty && !text.startsWith("/")) {
              aliasEntry.urlController.text = "/$text";
              aliasEntry.urlController.selection = TextSelection.fromPosition(
                TextPosition(offset: aliasEntry.urlController.text.length),
              );
            }

            _validateVirtualHost(entry);
            _saveVirtualHostsToConfiguration();
          }
        });

        aliasEntry.dirFocusNode.addListener(() {
          if (!aliasEntry.dirFocusNode.hasFocus) {
            String text = aliasEntry.dirController.text.trim();

            if (text.contains(r'\' )) {
              aliasEntry.dirController.text = text.replaceAll(r'\', '/');
              aliasEntry.dirController.selection = TextSelection.fromPosition(
                TextPosition(offset: aliasEntry.dirController.text.length),
              );
            }

            _validateVirtualHost(entry);
            _saveVirtualHostsToConfiguration();
          }
        });

        entry.aliases.add(aliasEntry);
      }

      entry.serverNameFocusNode.addListener(() {
        if (!entry.serverNameFocusNode.hasFocus) {
          if (entry.serverNameController.text.trim().isEmpty) {
            entry.serverNameController.text = "localhost";
          }

          _validateVirtualHost(entry);
          _saveVirtualHostsToConfiguration();
        }
      });

      entry.documentRootFocusNode.addListener(() {
        if (!entry.documentRootFocusNode.hasFocus) {
          String text = entry.documentRootController.text.trim();

          if (text.contains(r'\')) {
            entry.documentRootController.text = text.replaceAll(r'\', '/');
            entry.documentRootController.selection = TextSelection.fromPosition(
              TextPosition(offset: entry.documentRootController.text.length),
            );
          }

          _validateVirtualHost(entry);
          _saveVirtualHostsToConfiguration();
        }
      });

      _vhosts.add(entry);
    }

    setState(() {});
  }

  void _addVirtualHost() {
    final vhost = _VirtualHostEntry(
      port: _availablePorts.isNotEmpty ? _availablePorts[0]["port"].toString() : "",
      serverName: "localhost",
      documentRoot: "",
    );

    vhost.serverNameFocusNode.addListener(() {
      if (!vhost.serverNameFocusNode.hasFocus) {
        _validateVirtualHost(vhost);
        _saveVirtualHostsToConfiguration();
      }
    });

    vhost.documentRootFocusNode.addListener(() {
      if (!vhost.documentRootFocusNode.hasFocus) {
        String text = vhost.documentRootController.text.trim();

        if (text.contains(r'\')) {
          vhost.documentRootController.text = text.replaceAll(r'\', '/');
          vhost.documentRootController.selection = TextSelection.fromPosition(
            TextPosition(offset: vhost.documentRootController.text.length),
          );
        }

        _validateVirtualHost(vhost);
        _saveVirtualHostsToConfiguration();
      }
    });

    setState(() {
      _vhosts.add(vhost);
    });
  }

  void _validateVirtualHost(_VirtualHostEntry currentVhost) {
    setState(() {
      // Validate Server Name
      final name = currentVhost.serverNameController.text.trim();
      if (name.isEmpty) {
        // No error if it's empty — assume default was applied
        currentVhost.serverNameError = null;
      } else {
        bool duplicate = _vhosts.any((other) =>
        other != currentVhost &&
            other.port == currentVhost.port &&
            other.serverNameController.text.trim().toLowerCase() ==
                name.toLowerCase());

        currentVhost.serverNameError = duplicate ? "Duplicate on same port" : null;
      }

      // Validate Document Root
      currentVhost.documentRootError = currentVhost.documentRootController.text.trim().isEmpty
          ? "Document Root is required"
          : null;

      // Validate aliases
      for (final alias in currentVhost.aliases) {
        final url = alias.urlController.text.trim();
        final dir = alias.dirController.text.trim();

        if (url.isEmpty && dir.isEmpty) {
          alias.urlError = null;
          alias.dirError = null;
        } else if (url.isEmpty) {
          alias.urlError = "URL path is required";
          alias.dirError = null;
        } else if (!url.startsWith("/")) {
          alias.urlError = "URL must start with a /";
          alias.dirError = null;
        } else if (url.contains(" ")) {
          alias.urlError = "URL must not contain spaces";
          alias.dirError = null;
        } else if (dir.isEmpty) {
          alias.urlError = null;
          alias.dirError = "Directory path is required";
        } else {
          alias.urlError = null;
          alias.dirError = null;
        }
      }
    });
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
                              title: 'Virtual Hosts',
                              helpText: 'Define Apache virtual hosts for different ports and domains.',
                            ),
                            const SizedBox(height: 16),
                            _buildAddButton(),
                            ..._vhosts.map((vhost) => Padding(
                              padding: const EdgeInsets.only(top: 8), // double the spacing (was ~16)
                              child: _buildVirtualHostUI(vhost),
                            )),
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

  Widget _buildAddButton() {
    return Row(
      children: [
        const SizedBox(width: 16),
        SizedBox(
          width: 200,
          child: ElevatedButton.icon(
            onPressed: _addVirtualHost,
            icon: const Icon(Icons.add, color: Color(0xFFECEFF1)),
            label: const Text("Add Virtual Host"),
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
    );
  }

  Widget _buildVirtualHostUI(_VirtualHostEntry vhost) {
    final availablePortStrings = _availablePorts.map((e) => e["port"].toString()).toSet();
    final isPortMissing = !availablePortStrings.contains(vhost.port);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), // bottom now 8 instead of 16
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: const Color(0xFFECEFF1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 First Row: Port + Delete Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("Port", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.white,
                  ),
                  child: DropdownButtonFormField<String>(
                    value: vhost.port,
                    items: isPortMissing
                        ? [
                      DropdownMenuItem<String>(
                        value: vhost.port,
                        child: Text(
                          vhost.port,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    ]
                        : availablePortStrings.map((port) {
                      return DropdownMenuItem<String>(
                        value: port,
                        child: Text(port),
                      );
                    }).toList(),
                    onChanged: isPortMissing
                        ? null // Make the dropdown read-only if port is invalid
                        : (val) {
                      setState(() {
                        vhost.port = val ?? "";
                        _validateVirtualHost(vhost);
                        _saveVirtualHostsToConfiguration();
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      errorText: isPortMissing
                          ? "Port not defined. Go to Ports page to fix."
                          : null,
                    ),
                  ),
                ),
              ),
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
                      value: vhost.isActive,
                      onChanged: (val) {
                        setState(() {
                          vhost.isActive = val ?? true;
                          _saveVirtualHostsToConfiguration();
                        });
                      },
                    ),
                    const Text("Active"),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  bool? confirmDelete = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text(
                          'Delete Virtual Host "${vhost.serverNameController.text}"?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: Text('Are you sure you want to delete this Virtual Host on port ${vhost.port}?'),
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
                    setState(() {
                      _vhosts.remove(vhost);
                      _saveVirtualHostsToConfiguration();
                    });
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 🔹 Second Row: Server Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("Server Name", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: vhost.serverNameController,
                      focusNode: vhost.serverNameFocusNode,
                      onChanged: (_) => _validateVirtualHost(vhost),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hoverColor: Colors.transparent,
                        isDense: true,
                        hintText: "localhost",
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: vhost.serverNameError != null ? Colors.red : Colors.black,
                            width: 2,
                          ),
                        ),
                        errorText: vhost.serverNameError,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      cursorColor: Colors.black,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48), // Align with delete icon space
            ],
          ),

          const SizedBox(height: 12),

          // 🔹 Third Row: Document Root
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("Document Root", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: vhost.documentRootController,
                      focusNode: vhost.documentRootFocusNode,
                      onChanged: (_) => _validateVirtualHost(vhost),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hoverColor: Colors.transparent,
                        isDense: true,
                        hintText: "C:/path/to/folder",
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: vhost.documentRootError != null ? Colors.red : Colors.black,
                            width: 2,
                          ),
                        ),
                        errorText: vhost.documentRootError,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      cursorColor: Colors.black,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),

          // 🔽 Alias Section (unchanged)
          const SizedBox(height: 16),
          const Text("Aliases", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 16),
              SizedBox(
                width: 128,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      final alias = _AliasEntry();
                      alias.urlFocusNode.addListener(() {
                        if (!alias.urlFocusNode.hasFocus) {
                          final text = alias.urlController.text.trim();
                          if (text.isNotEmpty && !text.startsWith("/")) {
                            alias.urlController.text = "/$text";
                            alias.urlController.selection = TextSelection.fromPosition(
                              TextPosition(offset: alias.urlController.text.length),
                            );
                          }

                          _validateVirtualHost(vhost);
                          _saveVirtualHostsToConfiguration();
                        }
                      });

                      alias.dirFocusNode.addListener(() {
                        if (!alias.dirFocusNode.hasFocus) {
                          String text = alias.dirController.text.trim();

                          if (text.contains(r'\' )) {
                            alias.dirController.text = text.replaceAll(r'\', '/');
                            alias.dirController.selection = TextSelection.fromPosition(
                              TextPosition(offset: alias.dirController.text.length),
                            );
                          }

                          _validateVirtualHost(vhost);
                          _saveVirtualHostsToConfiguration();
                        }
                      });

                      vhost.aliases.add(alias);
                    });
                  },
                  icon: const Icon(Icons.add, color: Color(0xFFECEFF1)),
                  label: const Text("Add Alias"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78909C),
                    foregroundColor: const Color(0xFFECEFF1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    minimumSize: const Size(168, 40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vhost.aliases.isNotEmpty)
            Column(
              children: vhost.aliases.asMap().entries.map((entry) {
                int index = entry.key;
                _AliasEntry alias = entry.value;
                return _buildAliasEntry(alias, index, vhost);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAliasEntry(_AliasEntry alias, int index, _VirtualHostEntry vhost) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: const Color(0xFFCFD8DC),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL Path Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text("URL Path", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: alias.urlController,
                    focusNode: alias.urlFocusNode,
                    onChanged: (_) => _validateVirtualHost(vhost),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hoverColor: Colors.transparent,
                      isDense: true,
                      hintText: "/alias",
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: alias.urlError != null ? Colors.red : Colors.black,
                          width: 2,
                        ),
                      ),
                      errorText: alias.urlError,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    cursorColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final url = alias.urlController.text.trim().isEmpty ? "(no URL)" : alias.urlController.text.trim();

                    bool? confirmDelete = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          title: Text(
                            'Delete Alias "$url"?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: Text('Are you sure you want to delete this alias from Virtual Host on port ${vhost.port}?'),
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
                      setState(() {
                        vhost.aliases.removeAt(index);
                        _saveVirtualHostsToConfiguration();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Directory Path Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text("Directory Path", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: alias.dirController,
                    focusNode: alias.dirFocusNode,
                    onChanged: (_) => _validateVirtualHost(vhost),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hoverColor: Colors.transparent,
                      isDense: true,
                      hintText: "C:/path/to/folder",
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: alias.dirError != null ? Colors.red : Colors.black,
                          width: 2,
                        ),
                      ),
                      errorText: alias.dirError,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    cursorColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveVirtualHostsToConfiguration() {
    if (widget.activeConfigurationPath.isEmpty) return;

    final file = File(widget.activeConfigurationPath);
    if (!file.existsSync()) return;

    Map<String, dynamic> configData = jsonDecode(file.readAsStringSync());
    configData["settings"] ??= {};

    List<Map<String, dynamic>> vhostList = _vhosts.map((vhost) {
      return {
        "port": vhost.port,
        "active": vhost.isActive,
        "server_name": vhost.serverNameController.text.trim(),
        "document_root": vhost.documentRootController.text.trim(),
        "aliases": vhost.aliases.map((alias) {
          return {
            "url": alias.urlController.text.trim(),
            "dir": alias.dirController.text.trim(),
          };
        }).toList(),
      };
    }).toList();

    configData["settings"]["virtual_hosts"] = vhostList;

    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(configData));
  }
}
