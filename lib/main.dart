import 'dart:convert';
import 'dart:io';
import 'package:httpd_settings/server_info_page.dart';
import 'package:tuple/tuple.dart';


import 'package:flutter/material.dart';
import 'configuration_info_page.dart';
import 'parameters.dart';
import 'srvroot_page.dart';
import 'ports_page.dart';
import 'virtual_hosts_page.dart';
import 'package:intl/intl.dart';
import 'toolbar.dart';
import 'servers.dart';
import 'configurations.dart';
import 'locations_page.dart';
import 'configurations_page.dart';
import 'config_content_panel.dart'; // Add this line

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'httpd Settings',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  String _selectedOption = 'Servers';
  String? _selectedTreeViewItem;

  // Track the active Server Location and Configuration
  String _activeLocation = '';
  String _activeConfigurationName = '';  // Store name
  String _activeConfigurationId = '';    // Store ID


  final GlobalKey<SrvRootPageState> srvRootPageKey = GlobalKey<SrvRootPageState>();
  final GlobalKey<PortsPageState> portsPageKey = GlobalKey<PortsPageState>();
  final GlobalKey<VirtualHostsPageState> virtualHostsPageKey = GlobalKey<VirtualHostsPageState>();
  final GlobalKey<ConfigContentPanelState> configPanelKey = GlobalKey<ConfigContentPanelState>();

  @override
  void initState() {
    super.initState();
    _loadActiveServerLocationFromDisk();
    _loadActiveConfigurationFromDisk();

    // Select default sub-item on app start
    if (_selectedOption == 'Servers' && _selectedTreeViewItem == null) {
      _selectedTreeViewItem = 'Server Info';
    } else if (_selectedOption == 'Configurations' && _selectedTreeViewItem == null) {
      _selectedTreeViewItem = 'Configuration Info';
    } else if (_selectedOption == 'Parameters' && _selectedTreeViewItem == null) {
      _selectedTreeViewItem = 'SRVROOT';
    }
  }

  void _setActiveLocation(String location) {
    setState(() {
      _activeLocation = location;
    });
  }

  void _setActiveConfiguration(String configName, String configId) {
    setState(() {
      _activeConfigurationName = configName;
      _activeConfigurationId = configId;
    });
  }

  String _getActiveConfigPath() {
    if (_activeConfigurationId.isEmpty) return '';

    // Get the folder where app configurations (JSONs) are saved
    final String executablePath = File(Platform.resolvedExecutable).parent.path;
    final String configFolderPath = '$executablePath/httpd_settings_data/configurations';

    // The full path to the selected configuration file
    return '$configFolderPath/$_activeConfigurationId.json';
  }

  void _loadActiveServerLocationFromDisk() {
    final executablePath = File(Platform.resolvedExecutable).parent.path;
    final serversPath = '$executablePath/httpd_settings_data/servers.json';

    final file = File(serversPath);
    if (!file.existsSync()) return;

    final data = jsonDecode(file.readAsStringSync());
    final int activeIndex = data['activeIndex'];
    final List servers = data['servers'];

    if (activeIndex >= 0 && activeIndex < servers.length) {
      _activeLocation = servers[activeIndex]['path'];
    }
  }

  void _loadActiveConfigurationFromDisk() {
    final String executablePath = File(Platform.resolvedExecutable).parent.path;
    final String configFolder = '$executablePath/httpd_settings_data/configurations';
    final String activeConfigPath = '$configFolder/active_config.json';

    final File activeFile = File(activeConfigPath);
    if (!activeFile.existsSync()) return;

    final Map<String, dynamic> activeData = jsonDecode(activeFile.readAsStringSync());
    final String? activeId = activeData['activeId'];

    if (activeId == null) return;

    final File configFile = File('$configFolder/$activeId.json');
    if (!configFile.existsSync()) return;

    final Map<String, dynamic> config = jsonDecode(configFile.readAsStringSync());
    _activeConfigurationId = config['id'] ?? '';
    _activeConfigurationName = config['name'] ?? '';
  }

  void _readConfiguration() async {
    if (_activeLocation.isEmpty || _activeConfigurationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Both a Server Location and a Configuration must be active!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ask for user confirmation before overwriting configuration
    bool? confirmRead = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Match existing dialog style
          title: Text(
            "Overwrite Active Configuration \"$_activeConfigurationName\"?",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Reading configuration will overwrite existing configuration parameters. Do you want to continue?",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF78909C), // Same as cancel button
                foregroundColor: const Color(0xFFECEFF1), // Match text color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false), // No
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // ✅ Changed to green
                foregroundColor: const Color(0xFFECEFF1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true), // Yes
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );

    if (confirmRead != true) return; // Stop execution if the user selects "No"

    // Proceed with reading configuration
    String configFilePath = '$_activeLocation/Apache24/conf/httpd.conf';
    File configFile = File(configFilePath);

    if (!configFile.existsSync()) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('httpd.conf not found in the active Server Location!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Extract SRVROOT from Define directive
    String? extractedSrvRoot;
    for (String line in configFile.readAsLinesSync()) {
      line = line.trim();
      if (line.startsWith("Define SRVROOT")) {
        final match = RegExp(r'Define SRVROOT\s+"(.+)"').firstMatch(line);
        if (match != null && match.groupCount == 1) {
          extractedSrvRoot = match.group(1);
          break;
        }
      }
    }

    // Save SRVROOT to config file
    if (extractedSrvRoot != null) {
      String configFilePath = _getActiveConfigPath();
      if (configFilePath.isNotEmpty) {
        File configJsonFile = File(configFilePath);
        Map<String, dynamic> configData = {};

        if (configJsonFile.existsSync()) {
          configData = jsonDecode(configJsonFile.readAsStringSync());
        }

        configData["settings"] ??= {};
        configData["settings"]["srvroot"] = extractedSrvRoot;

        configJsonFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(configData));
      }
    }

    // Read ports from httpd.conf
    Map<String, dynamic> extractedPorts = _extractPortsFromConfig(configFile);

    if (extractedPorts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid ports found in httpd.conf!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Save ports to the active configuration
    _savePortsToActiveConfiguration(extractedPorts);

    String vhostsPath = '$_activeLocation/Apache24/conf/extra/httpd-vhosts.conf';
    File vhostsFile = File(vhostsPath);

    if (!vhostsFile.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('httpd-vhosts.conf not found in the active Server Location!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _extractVirtualHostsFromConfig(vhostsFile);

    srvRootPageKey.currentState?.updateSrvRoot();
    portsPageKey.currentState?.updatePorts();
    virtualHostsPageKey.currentState?.updateVirtualHosts();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Active configuration has been updated from server files (SRVROOT, Ports, Virtual Hosts).'),
        backgroundColor: Colors.green,
      ),
    );

    configPanelKey.currentState?.updateContent([
      _buildConfigSection(
        title: 'httpd.conf (SRVROOT) read on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/httpd.conf',
        match: '# Parameter "SRVROOT"',
        before: 5,
        after: 5,
        includeMatchLineOnly: false,
      ),
      _buildPortsSection(
        title: 'httpd.conf (Ports) read on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/httpd.conf',
        before: 5,
        after: 5,
      ),
      _buildVirtualHostsSection(
        title: 'httpd-vhosts.conf (Virtual Hosts) read on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/extra/httpd-vhosts.conf',
        before: 5,
        after: 5,
      ),
    ]);
  }

  Map<String, dynamic> _extractPortsFromConfig(File configFile) {
    List<String> lines = configFile.readAsLinesSync();
    List<Map<String, dynamic>> httpPorts = [];
    List<Map<String, dynamic>> httpsPorts = [];

    for (String line in lines) {
      String trimmed = line.trim();
      if (!trimmed.contains("Listen")) continue;

      bool isCommented = trimmed.startsWith("#");
      String lineToParse = isCommented ? trimmed.substring(1).trim() : trimmed;

      if (lineToParse.startsWith("Listen ")) {
        final parts = lineToParse.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          int? port = int.tryParse(parts[1]);
          if (port != null) {
            bool isHttps = parts.length > 2 && parts[2].toLowerCase() == "https";

            if (isHttps) {
              httpsPorts.add({
                "port": port,
                "active": !isCommented,
              });
            } else {
              httpPorts.add({
                "port": port,
                "active": !isCommented,
              });
            }
          }
        }
      }
    }

    if (httpPorts.isEmpty) {
      httpPorts.add({"port": 80, "active": true});
    }
    if (httpsPorts.isEmpty) {
      httpsPorts.add({"port": 443, "active": true});
    }

    return {
      "http_ports": httpPorts,
      "https_ports": httpsPorts,
    };
  }

  void _savePortsToActiveConfiguration(Map<String, dynamic> portsData) {
    String configFilePath = _getActiveConfigPath();
    if (configFilePath.isEmpty) return;

    File configFile = File(configFilePath);
    configFile.parent.createSync(recursive: true);

    Map<String, dynamic> configData = {};
    if (configFile.existsSync()) {
      configData = jsonDecode(configFile.readAsStringSync());
    }

    configData["settings"] ??= {};
    configData["settings"]["http_ports"] = portsData["http_ports"];
    configData["settings"]["https_ports"] = portsData["https_ports"];

    configFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(configData));
  }

  void _writeConfiguration() async {
    if (_activeLocation.isEmpty || _activeConfigurationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Both a Server Location and a Configuration must be active!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool? confirmWrite = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            "Write Configuration \"$_activeConfigurationName\" to Server",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "This will update the server with the current configuration parameters. Do you want to proceed?",
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
              child: const Text("No"),
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
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );

    if (confirmWrite != true) return;

    String configFilePath = '$_activeLocation/Apache24/conf/httpd.conf';
    File configFile = File(configFilePath);

    if (!configFile.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('httpd.conf not found in the active Server Location!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String configJsonPath = _getActiveConfigPath();
    String timestamp = _getFormattedTimestamp();

    // Load SRVROOT
    String? srvroot;
    if (configJsonPath.isNotEmpty && File(configJsonPath).existsSync()) {
      final json = jsonDecode(File(configJsonPath).readAsStringSync());
      srvroot = json["settings"]?["srvroot"];
    }

    // Load ports
    List<Map<String, dynamic>> httpPorts = [{"port": 80, "active": true}];
    List<Map<String, dynamic>> httpsPorts = [{"port": 443, "active": true}];

    if (configJsonPath.isNotEmpty && File(configJsonPath).existsSync()) {
      final json = jsonDecode(File(configJsonPath).readAsStringSync());
      final settings = json["settings"] ?? {};

      if (settings["http_ports"] is List) {
        httpPorts = List<Map<String, dynamic>>.from(settings["http_ports"]);
      }

      if (settings["https_ports"] is List) {
        httpsPorts = List<Map<String, dynamic>>.from(settings["https_ports"]);
      }
    }

    // SRVROOT comment line
    String srvRootComment = '# Parameter "SRVROOT" put from app "httpd Settings" for configuration "$_activeConfigurationName" on $timestamp';

    List<String> lines = configFile.readAsLinesSync();
    List<String> newLines = [];

    bool srvRootWritten = false;
    int? insertIndexAfterComments;
    int? insertIndexAfterSrvRoot;

    // Step 1: Scan for insert points
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.contains("Listen: Allows you to bind Apache")) {
        insertIndexAfterComments = i + 6; // Skip the full comment block
      }

      if (line.startsWith("Define SRVROOT")) {
        insertIndexAfterSrvRoot = i + 1;
      }
    }

    // Step 2: Clean and collect all non-port-related lines
    bool skippingOldPortBlock = false;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      // Skip app-managed port block (Listen + parameter comments)
      if (line.startsWith('# Parameter "HTTP Port') ||
          line.startsWith('# Parameter "HTTPS Port') ||
          line.startsWith('Listen ') ||
          line.startsWith('# Listen ')) {
        skippingOldPortBlock = true;
        continue;
      }

      // Skip blank lines immediately after our previous port block
      if (skippingOldPortBlock && line.isEmpty) {
        continue;
      }

      skippingOldPortBlock = false;

      // Clean up old SRVROOT comment if needed
      if (line.startsWith('# Parameter "SRVROOT"')) continue;
      if (line.startsWith("Define SRVROOT")) {
        if (!srvRootWritten && srvroot != null) {
          newLines.add(srvRootComment);
          newLines.add('Define SRVROOT "$srvroot"');
          srvRootWritten = true;
        }
        continue;
      }

      newLines.add(lines[i]);
    }

    // Step 3: Build the port block to insert
    List<String> portBlock = [];

    portBlock.add(""); // Empty line before HTTP

    for (int i = 0; i < httpPorts.length; i++) {
      final p = httpPorts[i];
      int port = p["port"];
      bool active = p["active"];

      String comment = '# Parameter "HTTP Port ${i + 1}"'
          '${active ? '' : ' (inactive)'} put from app "httpd Settings" for configuration "$_activeConfigurationName" on $timestamp';
      String listen = "Listen $port http";

      portBlock.add(comment);
      portBlock.add(active ? listen : "# $listen");
    }

    portBlock.add(""); // Empty line between groups

    for (int i = 0; i < httpsPorts.length; i++) {
      final p = httpsPorts[i];
      int port = p["port"];
      bool active = p["active"];

      String comment = '# Parameter "HTTPS Port ${i + 1}"'
          '${active ? '' : ' (inactive)'} put from app "httpd Settings" for configuration "$_activeConfigurationName" on $timestamp';
      String listen = "Listen $port https";

      portBlock.add(comment);
      portBlock.add(active ? listen : "# $listen");
    }

    portBlock.add(""); // Empty line after HTTPS block

    // Step 4: Determine insertion index
    int insertAt = insertIndexAfterComments ??
        insertIndexAfterSrvRoot ??
        0; // If nothing, insert at top

    newLines.insertAll(insertAt, portBlock);

    // Ensure the vhosts include line is uncommented
    bool foundInclude = false;
    for (int i = 0; i < newLines.length; i++) {
      final trimmed = newLines[i].trim();
      if (trimmed == '#Include conf/extra/httpd-vhosts.conf') {
        newLines[i] = 'Include conf/extra/httpd-vhosts.conf';
        foundInclude = true;
        break;
      } else if (trimmed == 'Include conf/extra/httpd-vhosts.conf') {
        foundInclude = true;
        break;
      }
    }

    // If not found, append it at the end
    if (!foundInclude) {
      newLines.add('');
      newLines.add('Include conf/extra/httpd-vhosts.conf');
    }

    // Step 5: Write back to httpd.conf
    configFile.writeAsStringSync(newLines.join('\n'));

    // Step 6: Write VirtualHosts to httpd-vhosts.conf
    String vhostsPath = '$_activeLocation/Apache24/conf/extra/httpd-vhosts.conf';
    File vhostsFile = File(vhostsPath);

    if (!vhostsFile.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('httpd-vhosts.conf not found in the active Server Location!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<String> vhostLines = [];
    final configData = jsonDecode(File(configJsonPath).readAsStringSync());
    final vhosts = (configData["settings"]?["virtual_hosts"] as List?) ?? [];

    for (int i = 0; i < vhosts.length; i++) {
      final v = vhosts[i];

      final port = v["port"] ?? "";
      final serverName = v["server_name"] ?? "";
      final documentRoot = v["document_root"] ?? "";
      final aliases = (v["aliases"] as List?) ?? [];
      final active = v["active"] != false; // default to true

      String header = '# Parameter "VirtualHost ${i + 1}"'
          '${active ? '' : ' (inactive)'} put from app "httpd Settings" for configuration "$_activeConfigurationName" on $timestamp';

      List<String> block = [];

      block.add('<VirtualHost *:$port>');
      block.add('    ServerName $serverName');
      block.add('    DocumentRoot "$documentRoot"');
      block.add('');

      for (final alias in aliases) {
        final url = alias["url"] ?? "";
        final dir = alias["dir"] ?? "";
        if (url.isEmpty || dir.isEmpty) continue;

        block.add('    Alias $url "$dir"');
        block.add('    <Directory "$dir">');
        block.add('        Options Indexes FollowSymLinks');
        block.add('        AllowOverride All');
        block.add('        Require all granted');
        block.add('    </Directory>');
        block.add('');
      }

      block.add('</VirtualHost>');

      if (!active) {
        block = block.map((line) => '# $line').toList();
        block.insert(0, '#'); // separator line above
        block.add('#');       // separator line below
      }

      vhostLines.add(header);
      vhostLines.addAll(block);
      vhostLines.add(''); // extra newline
    }

    List<String> originalLines = [];
    if (vhostsFile.existsSync()) {
      originalLines = vhostsFile.readAsLinesSync();
    }

    final configLabel = _activeConfigurationName;
    final beginMarkerRead =
        '# >>> BEGIN parameters "Virtual Host" put from app';
    final endMarkerRead =
        '# <<< END parameters "Virtual Host" put from app';
    final beginMarkerWrite =
        '# >>> BEGIN parameters "Virtual Host" put from app "httpd Settings" for configuration "$configLabel"';
    final endMarkerWrite =
        '# <<< END parameters "Virtual Host" put from app "httpd Settings" for configuration "$configLabel"';

    List<String> before = [];
    List<String> after = [];
    bool inGeneratedBlock = false;
    bool foundBegin = false;
    bool foundEnd = false;

    for (final line in originalLines) {
      if (line.trim().startsWith(beginMarkerRead)) {
        foundBegin = true;
        inGeneratedBlock = true;
        continue;
      }
      if (line.trim().startsWith(endMarkerRead)) {
        foundEnd = true;
        inGeneratedBlock = false;
        continue;
      }
      if (!inGeneratedBlock) {
        if (!foundBegin) {
          before.add(line);
        } else if (foundBegin && foundEnd) {
          after.add(line);
        }
      }
    }

    // Build new block
    List<String> generatedBlock = [];
    generatedBlock.add(beginMarkerWrite);
    generatedBlock.add('');
    generatedBlock.addAll(vhostLines);
    generatedBlock.add(endMarkerWrite);

    // Combine all
    List<String> finalLines = [];
    finalLines.addAll(before);
    if (before.isNotEmpty && before.last.trim().isNotEmpty) {
      finalLines.add(''); // spacing
    }
    finalLines.addAll(generatedBlock);
    if (after.isNotEmpty && generatedBlock.isNotEmpty) {
      finalLines.add(''); // spacing
    }
    finalLines.addAll(after);

    vhostsFile.writeAsStringSync(finalLines.join('\n'));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Active configuration has been written to server files (SRVROOT, Ports, Virtual Hosts).'),
        backgroundColor: Colors.green,
      ),
    );

    configPanelKey.currentState?.updateContent([
      _buildConfigSection(
        title: 'httpd.conf (SRVROOT) written on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/httpd.conf',
        match: '# Parameter "SRVROOT"',
        before: 5,
        after: 5,
        includeMatchLineOnly: false,
      ),
      _buildPortsSection(
        title: 'httpd.conf (Ports) written on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/httpd.conf',
        before: 5,
        after: 5,
      ),
      _buildVirtualHostsSection(
        title: 'httpd-vhosts.conf (Virtual Hosts) written on ${_getFormattedTimestamp()}',
        configFilePath: '$_activeLocation/Apache24/conf/extra/httpd-vhosts.conf',
        before: 5,
        after: 5,
      ),
    ]);
  }

  void updateConfigurationNameFromFile(String configPath) {
    final file = File(configPath);
    if (file.existsSync()) {
      final json = jsonDecode(file.readAsStringSync());
      final name = json['name'];
      if (name is String) {
        setState(() {
          _activeConfigurationName = name;
        });
      }
    }
  }

  ConfigSection _buildConfigSection({
    required String title,
    required String configFilePath,
    required String match,
    required int before,
    required int after,
    bool includeMatchLineOnly = false,
  }) {
    final lines = File(configFilePath).readAsLinesSync();
    int index = lines.indexWhere((l) => l.trim().startsWith(match));

    // --- Fallback logic ---
    bool fallbackUsed = false;
    if (index == -1) {
      if (match == '# Parameter "SRVROOT"') {
        index = lines.indexWhere((l) => l.trim().startsWith('Define SRVROOT'));
        fallbackUsed = index != -1;
      } else if (match.startsWith('# Parameter "HTTP Port')) {
        index = lines.indexWhere((l) =>
        l.trim().startsWith('Listen') && l.toLowerCase().contains('http'));
        fallbackUsed = index != -1;
      } else if (match.startsWith('# Parameter "HTTPS Port')) {
        index = lines.indexWhere((l) =>
        l.trim().startsWith('Listen') && l.toLowerCase().contains('https'));
        fallbackUsed = index != -1;
      }
    }

    // --- No match or fallback found ---
    if (index == -1) {
      return ConfigSection(
        title: '$title (no match found)',
        before: [],
        highlight: [Tuple2('<Match not found: "$match">', false)],
        after: [],
      );
    }

    final lineNumber = index + 1;

    final beforeLines = lines.sublist((index - before).clamp(0, index), index)
        .map((l) => l.trimRight())
        .toList();

    final highlightLines = includeMatchLineOnly
        ? [Tuple2(lines[index].trimRight(), false)]
        : [
      Tuple2(lines[index].trimRight(), false),
      if (index + 1 < lines.length) Tuple2(lines[index + 1].trimRight(), false),
    ];

    final afterStart = index + highlightLines.length;
    final afterLines = lines.sublist(afterStart, (afterStart + after).clamp(0, lines.length))
        .map((l) => l.trimRight())
        .toList();

    return ConfigSection(
      title: fallbackUsed
          ? '$title (fallback match at line $lineNumber)'
          : '$title (line $lineNumber)',
      before: beforeLines,
      highlight: highlightLines,
      after: afterLines,
    );
  }

  ConfigSection _buildPortsSection({
    required String title,
    required String configFilePath,
    required int before,
    required int after,
  }) {
    final lines = File(configFilePath).readAsLinesSync();

    // Find all relevant port lines (comments or Listen lines)
    final matchIndices = <int>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (line.startsWith('# parameter "http port') ||
          line.startsWith('# parameter "https port') ||
          line.startsWith('listen ') ||
          line.startsWith('# listen ')) {
        matchIndices.add(i);
      }
    }

    if (matchIndices.isEmpty) {
      return ConfigSection(
        title: '$title (no port-related lines found)',
        before: [],
        highlight: [Tuple2('<No Listen or Port comment lines found>', false)],
        after: [],
      );
    }

    // Determine block boundaries
    int minIndex = matchIndices.reduce((a, b) => a < b ? a : b);
    int maxIndex = matchIndices.reduce((a, b) => a > b ? a : b);

    final beforeStart = (minIndex - before).clamp(0, lines.length);
    final afterEnd = (maxIndex + after + 1).clamp(0, lines.length);

    final beforeLines = lines.sublist(beforeStart, minIndex).map((l) => l.trimRight()).toList();
    final highlightLines = lines.sublist(minIndex, maxIndex + 1).map((line) {
      final trimmed = line.trimRight();
      final inactive = trimmed.startsWith('# Listen') || trimmed.contains('(inactive)');
      return Tuple2(trimmed, inactive);
    }).toList();
    final afterLines = lines.sublist(maxIndex + 1, afterEnd).map((l) => l.trimRight()).toList();

    final portLineCount = matchIndices.where((i) {
      final l = lines[i].trim().toLowerCase();
      return l.startsWith('listen ') || l.startsWith('# listen ');
    }).length;

    return ConfigSection(
      title: '$title (starts at line ${minIndex + 1}, $portLineCount ports found)',
      before: beforeLines,
      highlight: highlightLines,
      after: afterLines,
    );
  }

  ConfigSection _buildVirtualHostsSection({
    required String title,
    required String configFilePath,
    required int before,
    required int after,
  }) {
    final lines = File(configFilePath).readAsLinesSync();
    final beginMarker = '# >>> BEGIN parameters "Virtual Host" put from app';
    final endMarker = '# <<< END parameters "Virtual Host" put from app';

    int beginIndex = lines.indexWhere((l) => l.trim().startsWith(beginMarker));
    int endIndex = lines.indexWhere((l) => l.trim().startsWith(endMarker));

    if (beginIndex == -1 || endIndex == -1 || endIndex <= beginIndex) {
      return ConfigSection(
        title: '$title (no generated Virtual Hosts block found)',
        before: [],
        highlight: [Tuple2('<Virtual Host block not found>', false)],
        after: [],
      );
    }

    // Extract context lines
    final beforeLines = lines
        .sublist((beginIndex - before).clamp(0, beginIndex), beginIndex)
        .map((l) => l.trimRight())
        .toList();

    final highlightLines = <Tuple2<String, bool>>[];
    bool currentInactive = false;

    for (int i = beginIndex; i <= endIndex; i++) {
      final line = lines[i].trimRight();

      if (line.trim().startsWith(endMarker)) {
        // END marker should always be black
        highlightLines.add(Tuple2(line, false));
        continue;
      }

      // Detect block header (VirtualHost line)
      if (line.contains('Parameter "VirtualHost')) {
        currentInactive = line.contains('(inactive)');
      }

      highlightLines.add(Tuple2(line, currentInactive));
    }

    final afterLines = lines
        .sublist(endIndex + 1, (endIndex + 1 + after).clamp(0, lines.length))
        .map((l) => l.trimRight())
        .toList();

    final vhostCount = highlightLines.where((t) =>
    t.item1.contains('Parameter "VirtualHost') &&
        !t.item1.contains('<<< END')
    ).length;

    return ConfigSection(
      title: '$title (lines ${beginIndex + 1}-${endIndex + 1}, $vhostCount virtual host${vhostCount == 1 ? '' : 's'})',
      before: beforeLines,
      highlight: highlightLines,
      after: afterLines,
    );
  }

  String _getFormattedTimestamp() {
    String locale = Platform.localeName; // Example: "en_US", "fr_FR", "de_DE"

    DateTime now = DateTime.now();
    bool isUS = locale.startsWith("en_US");

    if (isUS) {
      // US Format: "Monday, October 3, 2025 07:30:15 PM"
      return DateFormat("EEEE, MMMM d, yyyy 'at' hh:mm:ss a", "en_US").format(now);
    } else {
      // Europe Format: "Monday, 03 October 2025 19:30:15"
      return DateFormat("EEEE, dd MMMM yyyy 'at' HH:mm:ss").format(now);
    }
  }

  void _extractVirtualHostsFromConfig(File vhostsFile) {
    if (!vhostsFile.existsSync()) return;

    final beginMarker = '# >>> BEGIN parameters "Virtual Host" put from app';
    final endMarker = '# <<< END parameters "Virtual Host" put from app';

    final lines = vhostsFile.readAsLinesSync();
    final List<Map<String, dynamic>> virtualHosts = [];

    bool inBlock = false;
    List<String> currentBlock = [];
    bool currentIsActive = true;

    for (final line in lines) {
      if (line.trim().startsWith(beginMarker)) {
        inBlock = true;
        continue;
      } else if (line.trim().startsWith(endMarker)) {
        break;
      }

      if (!inBlock) continue;

      // Collect lines for a single VirtualHost block
      if (line.trim().startsWith('# Parameter "VirtualHost')) {
        if (currentBlock.isNotEmpty) {
          final parsed = _parseVirtualHostBlock(currentBlock, currentIsActive);
          if (parsed != null) {
            virtualHosts.add(parsed);
          }
          currentBlock = [];
        }
        currentIsActive = !line.contains('(inactive)');
      } else {
        currentBlock.add(line);
      }
    }

    if (currentBlock.isNotEmpty) {
      final parsed = _parseVirtualHostBlock(currentBlock, currentIsActive);
      if (parsed != null) {
        virtualHosts.add(parsed);
      }
    }

    // Save to active configuration
    final configFilePath = _getActiveConfigPath();
    if (configFilePath.isNotEmpty) {
      final configFile = File(configFilePath);
      Map<String, dynamic> configData = {};
      if (configFile.existsSync()) {
        configData = jsonDecode(configFile.readAsStringSync());
      }
      configData["settings"] ??= {};
      configData["settings"]["virtual_hosts"] = virtualHosts;

      configFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(configData));
    }
  }

  Map<String, dynamic>? _parseVirtualHostBlock(List<String> lines, bool isActive) {
    String? port;
    String? serverName;
    String? documentRoot;
    List<Map<String, String>> aliases = [];

    String? currentAlias;
    String? currentDir;

    for (String rawLine in lines) {
      String line = rawLine.trim();

      if (!isActive && line.startsWith("#")) {
        line = line.substring(1).trim(); // Remove comment prefix for parsing
      }

      if (line.startsWith('<VirtualHost')) {
        final match = RegExp(r'<VirtualHost \*:(\d+)>').firstMatch(line);
        if (match != null) port = match.group(1);
      } else if (line.startsWith('ServerName ')) {
        serverName = line.substring(11).trim();
      } else if (line.startsWith('DocumentRoot ')) {
        documentRoot = line.substring(13).replaceAll('"', '').trim();
      } else if (line.startsWith('Alias ')) {
        final parts = line.substring(6).trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          currentAlias = parts[0];
          currentDir = parts[1].replaceAll('"', '');
        }
      } else if (line.startsWith('<Directory')) {
        // Confirm the <Directory> matches the previous alias's dir
        final dirMatch = RegExp(r'<Directory\s+"([^"]+)">').firstMatch(line);
        if (dirMatch != null && currentAlias != null) {
          final dir = dirMatch.group(1);
          if (dir == currentDir) {
            aliases.add({
              "url": currentAlias,
              "dir": currentDir!,
            });
          }
          currentAlias = null;
          currentDir = null;
        }
      }
    }

    if (port == null || serverName == null || documentRoot == null) {
      return null;
    }

    return {
      "port": port,
      "server_name": serverName,
      "document_root": documentRoot,
      "aliases": aliases,
      "active": isActive,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double windowWidth = constraints.maxWidth;

        bool isPanelVisible = windowWidth > 1250;
        double panelWidth = (windowWidth > 1413) ? windowWidth - 1010 : 410;
        double? panelLeftOffset = (windowWidth > 1620) ? 1010 : null;

        double pageWidth = (windowWidth < 815) ? 640 :
          ((windowWidth > 815 && windowWidth < 1015) ? windowWidth - 370 :
            ((windowWidth > 1015 && windowWidth < 1250) ? 640 :
              ((windowWidth > 1250 && windowWidth < 1413) ? windowWidth - 780 :
                640)));

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: AppBar(
              backgroundColor: const Color(0xFFB0BEC5),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Push buttons to the right
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 110,
                                child: Text(
                                  "Server Location",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF263238),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _activeLocation.isNotEmpty ? _activeLocation : "None",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 110,
                                child: Text(
                                  "Configuration",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF263238),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _activeConfigurationId.isEmpty ? "None" : _activeConfigurationName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row( // Buttons aligned to the right
                        children: [
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _readConfiguration, // Now correctly triggers reading
                              icon: const Icon(Icons.file_download, color: Color(0xFFECEFF1)),
                              label: const Text('Read Configuration'),
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
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _writeConfiguration, // Now calls the new function
                              icon: const Icon(Icons.file_upload, color: Color(0xFFECEFF1)),
                              label: const Text('Write Configuration'),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Row(
                children: [
                  // Left Toolbar
                  Container(
                    width: 100,
                    color: const Color(0xFFCFD8DC),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ToolbarRadioButton(
                          icon: Icons.dns,
                          label: 'Servers',
                          isSelected: _selectedOption == 'Servers',
                          onTap: () {
                            setState(() {
                              _selectedOption = 'Servers';
                              _selectedTreeViewItem = 'Server Info';
                            });
                          },
                        ),
                        ToolbarRadioButton(
                          icon: Icons.settings,
                          label: 'Configurations',
                          isSelected: _selectedOption == 'Configurations',
                          onTap: () {
                            setState(() {
                              _selectedOption = 'Configurations';
                              _selectedTreeViewItem = 'Configuration Info';
                            });
                          },
                        ),
                        ToolbarRadioButton(
                          icon: Icons.list,
                          label: 'Parameters',
                          isSelected: _selectedOption == 'Parameters',
                          onTap: () {
                            setState(() {
                              _selectedOption = 'Parameters';
                              _selectedTreeViewItem = 'SRVROOT';
                            });
                          },
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // Tree View
                  SizedBox(
                    width: 270,
                    child: _selectedOption == 'Servers'
                        ? ServersTreeView(
                      selectedOption: _selectedOption,
                      selectedTreeViewItem: _selectedTreeViewItem,
                      onItemSelected: (item) {
                        setState(() {
                          _selectedTreeViewItem = item;
                        });
                      },
                    )
                        : _selectedOption == 'Configurations'
                        ? ConfigurationsTreeView(
                      selectedOption: _selectedOption,
                      selectedTreeViewItem: _selectedTreeViewItem,
                      onItemSelected: (item) {
                        setState(() {
                          _selectedTreeViewItem = item;
                        });
                      },
                    )
                        : _selectedOption == 'Parameters'
                        ? ParametersTreeView(
                      selectedOption: _selectedOption,
                      selectedTreeViewItem: _selectedTreeViewItem,
                      onItemSelected: (item) {
                        setState(() {
                          _selectedTreeViewItem = item;
                        });
                      },
                    )
                        : Center(
                      child: Text(
                        'No menu for $_selectedOption',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  // Main Dynamic Page
                  SizedBox(
                    width: pageWidth,
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: _selectedTreeViewItem == 'Locations'
                          ? LocationsPage(
                            onLocationSelected: _setActiveLocation,
                          )
                          : _selectedTreeViewItem == 'Saved Configurations'
                          ? ConfigurationsPage(
                            onConfigurationSelected: (configName, configId) {
                              _setActiveConfiguration(configName, configId);
                            },
                            onConfigurationRenamed: (newName) {
                              setState(() {
                                _activeConfigurationName = newName;
                              });
                            },
                          )
                          : _selectedTreeViewItem == 'Server Info'
                          ? ServerInfoPage(
                            activeServerLocation: _activeLocation,
                          )
                          : _selectedTreeViewItem == 'Configuration Info'
                              ? ConfigurationInfoPage(
                            activeConfigurationPath: _getActiveConfigPath(),
                          )
                          : _selectedTreeViewItem == 'SRVROOT'
                          ? SrvRootPage(
                            key: srvRootPageKey,
                            activeConfigurationPath: _getActiveConfigPath(),
                            activeServerLocation: _activeLocation,
                          )
                          : _selectedTreeViewItem == 'Ports'
                          ? PortsPage(
                            key: portsPageKey,
                            activeConfigurationPath: _getActiveConfigPath(),
                          )
                          : _selectedTreeViewItem == 'VirtualHosts'
                          ? VirtualHostsPage(
                            key: virtualHostsPageKey,
                            activeConfigurationPath: _getActiveConfigPath(),
                          )
                          : _selectedTreeViewItem != null
                          ? Text(
                            'Settings Page: $_selectedTreeViewItem',
                            style: const TextStyle(fontSize: 18),
                          )
                          : const Text(
                            'Please select an item from the TreeView',
                            style: TextStyle(fontSize: 18),
                          ),
                      ),
                    ),
                  ),
                ],
              ),
              // Config File Content Panel (Previously Help Panel)
              Positioned(
                left: panelLeftOffset,
                right: 0,
                child: Visibility(
                  visible: isPanelVisible,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: Container(
                    width: panelWidth,
                    height: constraints.maxHeight,
                    color: const Color(0xFFECEFF1),
                    child: ConfigContentPanel(
                      key: configPanelKey,
                      currentPage: _selectedTreeViewItem,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
