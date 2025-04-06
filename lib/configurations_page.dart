import 'dart:convert'; // For JSON encoding/decoding
import 'dart:io'; // For file system operations
import 'dart:math'; // For generating unique IDs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/section_delimiter.dart';

class ConfigurationsPage extends StatefulWidget {
  final Function(String, String) onConfigurationSelected;
  final Function(String) onConfigurationRenamed; // New callback

  const ConfigurationsPage({
    super.key,
    required this.onConfigurationSelected,
    required this.onConfigurationRenamed, // Receive callback
  });

  @override
  ConfigurationsPageState createState() => ConfigurationsPageState();
}

int? _editingIndex; // Tracks which configuration is being edited
final TextEditingController _editingController = TextEditingController();

class ConfigurationsPageState extends State<ConfigurationsPage> {
  final List<Map<String, dynamic>> _configurations = []; // List of configurations
  int _activeConfigIndex = -1; // Index of the active configuration (-1 means none)

  late final String _configFolderPath; // Folder for configurations
  late final String _activeConfigFilePath; // File storing the active configuration

  @override
  void initState() {
    super.initState();
    _editingIndex = null; // Ensure no configuration remains in edit mode

    // Determine the path of the .exe and set data paths
    final String executablePath = File(Platform.resolvedExecutable).parent.path;
    _configFolderPath = '$executablePath/httpd_settings_data/configurations';
    _activeConfigFilePath = '$_configFolderPath/active_config.json';

    _loadConfigurations(); // Load saved configurations on startup
  }

  // Load configurations from the folder
  void _loadConfigurations() {
    final Directory configDir = Directory(_configFolderPath);
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    final List<FileSystemEntity> files = configDir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.json')) {
        final String content = file.readAsStringSync();
        final Map<String, dynamic> configData = jsonDecode(content);

        // Ensure 'id' and 'name' are valid and exist in the file before adding
        if (configData.containsKey('id') && configData.containsKey('name')) {
          String id = configData['id'].toString();
          String name = configData['name'].toString();

          setState(() {
            _configurations.add({
              "id": id,
              "name": name,
              "settings": configData["settings"] ?? {},
            });

            // Sort the configurations list alphabetically by name (only on initial load)
            _configurations.sort((a, b) => a["name"].toLowerCase().compareTo(b["name"].toLowerCase()));
          });
        }
      }
    }

    // Load active configuration
    final File activeConfigFile = File(_activeConfigFilePath);
    if (activeConfigFile.existsSync()) {
      final String content = activeConfigFile.readAsStringSync();
      final Map<String, dynamic> activeData = jsonDecode(content);
      _activeConfigIndex = _configurations.indexWhere((c) => c['id'] == activeData['activeId']);
    }

    setState(() {});
  }

  // Save active configuration
  void _saveActiveConfiguration() {
    final Map<String, dynamic> data = {
      "activeId": _activeConfigIndex != -1 ? _configurations[_activeConfigIndex]['id'] : null,
    };

    final File file = File(_activeConfigFilePath);
    // Write the JSON data to the file with pretty formatting
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(data));
  }

  // Generate a unique 8-character alphanumeric ID
  String _generateUniqueId() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    return 'c${List.generate(7, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  // Create a new configuration
  void _createConfiguration() {
    String newId = _generateUniqueId();
    String defaultName = "Configuration ($newId)"; // Updated naming format

    Map<String, dynamic> newConfig = {
      "id": newId,
      "name": defaultName,
      "settings": {},
    };

    File file = File('$_configFolderPath/$newId.json');
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(newConfig));

    setState(() {
      _configurations.add(newConfig);
    });
  }

  // Remove a configuration
  void _removeConfiguration(int index) async {
    String configName = _configurations[index]['name'];
    String configFilePath = '$_configFolderPath/${_configurations[index]['id']}.json';

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Ensure background is white
          title: const Text(
            "Delete Configuration?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "$configName"?'),
              const SizedBox(height: 8),
              Text(
                'File Path:\n$configFilePath',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
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
      File file = File(configFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      setState(() {
        bool wasActive = _activeConfigIndex == index;

        if (wasActive) {
          _activeConfigIndex = -1;
        } else if (_activeConfigIndex > index) {
          _activeConfigIndex--;
        }

        _configurations.removeAt(index);
      });

      _saveActiveConfiguration();

      // If the removed configuration was active, update the top panel to "None"
      if (_activeConfigIndex == -1) {
        widget.onConfigurationSelected("None", '');
      }
    }
  }

  void _updateConfigurationName(int index, String newName) {
    String trimmedName = newName.trim();

    setState(() {
      if (trimmedName.isEmpty) {
        // If empty, restore the old name immediately
        _editingController.text = _configurations[index]['name'];
      } else if (trimmedName != _configurations[index]['name']) {
        // Save only if the name has changed
        _configurations[index]['name'] = trimmedName;

        // Save the updated name to the file
        File configFile = File('$_configFolderPath/${_configurations[index]['id']}.json');
        Map<String, dynamic> updatedConfig = {
          "id": _configurations[index]['id'],
          "name": trimmedName,
          "settings": _configurations[index]['settings'],
        };
        configFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(updatedConfig));

        // Notify MainPage if this was the active configuration
        if (index == _activeConfigIndex) {
          widget.onConfigurationRenamed(trimmedName);
        }
      }

      _editingIndex = null; // Ensure edit mode exits
    });
  }

  // Set a configuration as active
  void _setActiveConfiguration(int index) {
    setState(() {
      _activeConfigIndex = index;
    });

    _saveActiveConfiguration();

    // Notify MainPage about the active configuration change
    widget.onConfigurationSelected(_configurations[index]['name'], _configurations[index]['id']);
  }

  Color _getItemBackgroundColor(int index) {
    if (_editingIndex == index) {
      return const Color(0xFFECEFF1); // Light grey when editing (same as PortsPage)
    }
    return const Color(0xFFECEFF1); // Default grey background
  }

  void _cancelEditing(int index) {
    setState(() {
      _editingController.text = _configurations[index]['name']; // Restore original name
      _editingIndex = null; // Exit edit mode
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Colors.yellow, // Light grey selection
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
                        width: 640, // Fixed width for the content panel
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section title
                            SectionDelimiter(
                              title: 'Configurations',
                              helpText:
                              'Manage your Apache configurations. Each configuration is saved separately and can be activated as needed.',
                            ),
                            const SizedBox(height: 16),
                            // Buttons at the top
                            Row(
                              children: [
                                const SizedBox(width: 16),
                                // Button to add a new configuration
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton.icon(
                                    onPressed: _createConfiguration,
                                    icon: const Icon(Icons.add, color: Color(0xFFECEFF1)), // Icon color updated
                                    label: const Text('New Configuration'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF78909C), // Match LocationsPage button
                                      foregroundColor: const Color(0xFFECEFF1), // Match text color
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3.5), // Updated corner radius
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // List of configurations
                            if (_configurations.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _configurations.length,
                                itemBuilder: (context, index) {
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    color: _getItemBackgroundColor(index), // Apply correct background color
                                    child: ListTile(
                                      focusColor: _getItemBackgroundColor(index),
                                      contentPadding: const EdgeInsets.only(left: 16, right: 12),
                                      title: _editingIndex == index
                                          ? Focus(
                                        onFocusChange: (hasFocus) {
                                          if (!hasFocus) {
                                            _cancelEditing(index);
                                          }
                                        },
                                        child: KeyboardListener(
                                          focusNode: FocusNode(), // Needed for keyboard events
                                          onKeyEvent: (event) {
                                            if (event.logicalKey == LogicalKeyboardKey.escape) {
                                              _cancelEditing(index);
                                            }
                                          },
                                          child: TextField(
                                            controller: _editingController,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            style: const TextStyle(fontSize: 14),
                                            onSubmitted: (newValue) {
                                              _updateConfigurationName(index, newValue);
                                            },
                                          ),
                                        ),
                                      )
                                          : Text(
                                        _configurations[index]['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: index == _activeConfigIndex ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                            tooltip: 'Rename',
                                            onPressed: () {
                                              setState(() {
                                                _editingIndex = index;
                                                _editingController.text = _configurations[index]['name'];
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Remove',
                                            onPressed: () => _removeConfiguration(index),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _setActiveConfiguration(index),
                                    ),
                                  );
                                },
                              )
                            else
                              const Text(
                                'No configurations defined yet. Add a new one to get started!',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
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
}
