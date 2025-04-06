import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/section_delimiter.dart';

class ServerInfoPage extends StatefulWidget {
  final String activeServerLocation;

  const ServerInfoPage({
    super.key,
    required this.activeServerLocation,
  });

  @override
  State<ServerInfoPage> createState() => _ServerInfoPageState();
}

class _ServerInfoPageState extends State<ServerInfoPage> {
  String? _srvrootValue;
  List<Map<String, String>> _ports = [];
  List<Map<String, dynamic>> _vhostSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadServerInfo();
  }

  void _loadServerInfo() {
    final httpdPath = '${widget.activeServerLocation}/Apache24/conf/httpd.conf';
    final vhostPath = '${widget.activeServerLocation}/Apache24/conf/extra/httpd-vhosts.conf';

    _srvrootValue = null;
    _ports = [];
    _vhostSummaries = [];

    if (File(httpdPath).existsSync()) {
      final lines = File(httpdPath).readAsLinesSync();

      // Extract SRVROOT
      final srvrootLine = lines.firstWhere(
            (line) => line.trim().startsWith('Define SRVROOT'),
        orElse: () => '',
      );
      if (srvrootLine.isNotEmpty) {
        final parts = srvrootLine.trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          _srvrootValue = parts[2].replaceAll('"', '');
        }
      }

      // Extract Ports written by the app (comment + Listen line)
      for (int i = 0; i < lines.length - 1; i++) {
        final commentLine = lines[i].trim();
        final portLine = lines[i + 1].trim();

        final isHttp = commentLine.startsWith('# Parameter "HTTP Port');
        final isHttps = commentLine.startsWith('# Parameter "HTTPS Port');
        final isInsertedByApp = commentLine.contains('put from app "httpd Settings"');

        if ((isHttp || isHttps) && isInsertedByApp) {
          final isInactive = commentLine.contains('(inactive)');
          final cleanPortLine = portLine.replaceAll('#', '').trim();
          final parts = cleanPortLine.split(RegExp(r'\s+'));

          if (parts.length >= 2 && parts[0] == 'Listen') {
            final port = parts[1];
            final protocol = parts.length >= 3 ? parts[2].toUpperCase() : (isHttps ? 'HTTPS' : 'HTTP');
            _ports.add({
              "protocol": protocol,
              "port": port,
              "inactive": isInactive.toString(),
            });
          }
        }
      }
    }

    if (File(vhostPath).existsSync()) {
      final lines = File(vhostPath).readAsLinesSync();
      final start = lines.indexWhere((line) => line.contains('# >>> BEGIN parameters "Virtual Host"'));
      final end = lines.indexWhere((line) => line.contains('# <<< END parameters "Virtual Host"'));

      if (start != -1 && end != -1 && end > start) {
        final block = lines.sublist(start + 1, end);

        Map<String, dynamic>? currentHost;
        List<Map<String, String>> currentAliases = [];
        bool currentIsInactive = false;

        for (int i = 0; i < block.length; i++) {
          String line = block[i].trimRight();

          if (line.startsWith('# Parameter "VirtualHost')) {
            if (currentHost != null) {
              currentHost["aliases"] = currentAliases;
              _vhostSummaries.add(currentHost);
            }
            currentHost = {};
            currentAliases = [];
            currentIsInactive = line.contains('(inactive)');
            currentHost["active"] = !currentIsInactive;
          } else {
            // Clean line if inactive
            final clean = currentIsInactive && line.startsWith('#') ? line.substring(1).trim() : line.trim();

            if (clean.startsWith('<VirtualHost')) {
              final match = RegExp(r'<VirtualHost\s+\*:(\d+)>').firstMatch(clean);
              if (match != null && currentHost != null) {
                currentHost["port"] = match.group(1);
              }
            } else if (clean.startsWith('ServerName ')) {
              currentHost?["serverName"] = clean.substring(11).trim();
            } else if (clean.startsWith('DocumentRoot ')) {
              currentHost?["documentRoot"] = clean.substring(13).replaceAll('"', '').trim();
            } else if (clean.startsWith('Alias ')) {
              final parts = clean.substring(6).trim().split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                currentAliases.add({
                  "urlPath": parts[0],
                  "directory": parts[1].replaceAll('"', ''),
                });
              }
            }
          }
        }

        if (currentHost != null) {
          currentHost["aliases"] = currentAliases;
          _vhostSummaries.add(currentHost);
        }
      }
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
          const Text(
            "(No written configuration ports found)",
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
          )
        else
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _ports.map((portMap) {
              final protocol = portMap["protocol"] ?? "HTTP";
              final port = portMap["port"] ?? "";
              final isInactive = portMap["inactive"] == "true";

              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        protocol,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isInactive ? const Color(0xFFD17C00) : Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      port,
                      style: TextStyle(
                        fontSize: 14,
                        color: isInactive ? const Color(0xFFD17C00) : Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
          const Text(
            "(No  written configuration virtual hosts found)",
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
          )
        else
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _vhostSummaries.map((host) {
              final bool isInactive = host["active"] == false;
              final Color textColor = isInactive ? const Color(0xFFD17C00) : Colors.black;

              final List<Widget> rows = [];

              // Title
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "VirtualHost on port ${host["port"]}",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
              ));

              // ServerName + DocumentRoot
              if (host["serverName"] != null) {
                rows.add(_buildIndentedLabelValue("ServerName", host["serverName"], indent: 1, color: textColor));
              }
              if (host["documentRoot"] != null) {
                rows.add(_buildIndentedLabelValue("DocumentRoot", host["documentRoot"], indent: 1, color: textColor));
              }

              // Aliases
              final aliases = host["aliases"] as List<dynamic>? ?? [];
              for (int i = 0; i < aliases.length; i++) {
                rows.add(_buildIndentedLabel("Alias ${i + 1}", indent: 1, color: textColor));

                final url = aliases[i]["urlPath"] ?? "";
                final dir = aliases[i]["directory"] ?? "";

                rows.add(_buildIndentedLabelValue("URL Path", url, indent: 2, color: textColor));
                rows.add(_buildIndentedLabelValue("Directory", dir, indent: 2, color: textColor));
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildIndentedLabel(String label, {required int indent, required Color color}) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, bottom: 2),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
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
          Flexible(
            child: Text(value, style: TextStyle(fontSize: 14, color: color)),
          ),
        ],
      ),
    );
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
                            const SectionDelimiter(
                              title: "Server Info",
                              helpText: "Live values from the Apache server configuration files.",
                            ),
                            const SizedBox(height: 16),
                            _buildLabelValue(
                              "Server Location",
                              widget.activeServerLocation.trim().isEmpty ? "(Not found)" : widget.activeServerLocation,
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

  Widget _buildLabelValue(String label, String value) {
    final bool isNotFound = value.trim() == "(Not found)";
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
}
