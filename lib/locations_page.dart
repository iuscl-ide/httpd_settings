import 'dart:convert'; // For JSON encoding/decoding
import 'dart:io'; // For file system operations
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/section_delimiter.dart';

class LocationsPage extends StatefulWidget {
  final Function(String) onLocationSelected; // Callback function

  const LocationsPage({super.key, required this.onLocationSelected});

  @override
  LocationsPageState createState() => LocationsPageState();
}

class LocationsPageState extends State<LocationsPage> {
  final List<Map<String, dynamic>> _serverLocations = []; // List of servers
  int _activeServerIndex = -1; // Index of the active server (-1 means none)

  late final String _dataFolderPath; // Data folder path
  late final String _dataFilePath; // JSON file path

  @override
  void initState() {
    super.initState();

    // Determine the path of the .exe and set data paths
    final String executablePath = File(Platform.resolvedExecutable).parent.path;
    _dataFolderPath = '$executablePath/httpd_settings_data';
    _dataFilePath = '$_dataFolderPath/servers.json';

    _loadServers(); // Load saved data on app startup
  }

  // Load server locations from the JSON file
  void _loadServers() {
    final File file = File(_dataFilePath);

    if (file.existsSync()) {
      final String content = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      setState(() {
        _activeServerIndex = data['activeIndex'];
        _serverLocations.addAll(List<Map<String, dynamic>>.from(data['servers']));
      });
    }
  }

  // Save server locations to the JSON file
  void _saveServers() {
    final Map<String, dynamic> data = {
      "activeIndex": _activeServerIndex,
      "servers": _serverLocations,
    };

    final File file = File(_dataFilePath);

    // Ensure the data folder exists
    file.parent.createSync(recursive: true);

    // Write the JSON data to the file with pretty formatting
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(data));
  }

  // Method to add a new server location
  Future<void> _addServerLocation() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (!mounted) return; // ✅ FIX added here

    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      if (_serverLocations.any((location) => location['path'] == selectedDirectory)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This location is already added!'),
          ),
        );
        return;
      }

      setState(() {
        _serverLocations.add({'path': selectedDirectory, 'status': 'unverified'});
      });

      _saveServers(); // Save after adding
    }
  }

  // Method to remove a server location
  void _removeServerLocation(int index) async {
    String serverPath = _serverLocations[index]['path'];
    String verificationStatus;

    if (_serverLocations[index]['status'] == 'ok') {
      verificationStatus = "The server is verified and is OK.";
    } else if (_serverLocations[index]['status'] == 'error') {
      verificationStatus = "The server is verified but is not OK.";
    } else {
      verificationStatus = "The server is not verified.";
    }

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Ensure background is white
          title: const Text(
            "Delete Server Location?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "$serverPath"?'),
              const SizedBox(height: 8),
              Text(
                verificationStatus,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF78909C), // Same as Add Server button
                foregroundColor: const Color(0xFFECEFF1), // Match text color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5), // Match button style
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red for Delete button
                foregroundColor: const Color(0xFFECEFF1), // Match text color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.5), // Match button style
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        bool wasActive = _activeServerIndex == index;

        if (wasActive) {
          _activeServerIndex = -1;
        } else if (_activeServerIndex > index) {
          _activeServerIndex--;
        }

        _serverLocations.removeAt(index);
      });

      _saveServers();

      // If the removed server was active, update the top panel to "None"
      if (_activeServerIndex == -1) {
        widget.onLocationSelected("None");
      }
    }
  }

  // Method to set a server as active
  void _setActiveServer(int index) {
    setState(() {
      _activeServerIndex = index;
    });

    _saveServers(); // Save after changing active server

    // Notify the MainPage about the active location change
    widget.onLocationSelected(_serverLocations[index]['path']);
  }

  // Method to verify the active server
  void _verifyActiveServer() {
    if (_activeServerIndex == -1) return;

    final String path = _serverLocations[_activeServerIndex]['path'];
    final String apachePath = '$path/Apache24';

    if (!Directory(apachePath).existsSync()) {
      setState(() {
        _serverLocations[_activeServerIndex]['status'] = 'error';
      });
      _saveServers(); // Save verification result
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server verification failed: Missing "Apache24" folder'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool hasBin = Directory('$apachePath/bin').existsSync();
    bool hasConf = Directory('$apachePath/conf').existsSync();
    bool hasHttpdExe = File('$apachePath/bin/httpd.exe').existsSync();
    bool hasHttpdConf = File('$apachePath/conf/httpd.conf').existsSync();

    List<String> issues = [];
    if (!hasBin) issues.add("Missing 'bin' folder");
    if (!hasConf) issues.add("Missing 'conf' folder");
    if (!hasHttpdExe) issues.add("Missing 'httpd.exe' in 'bin' folder");
    if (!hasHttpdConf) issues.add("Missing 'httpd.conf' in 'conf' folder");

    setState(() {
      if (issues.isEmpty) {
        _serverLocations[_activeServerIndex]['status'] = 'ok';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _serverLocations[_activeServerIndex]['status'] = 'error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server verification failed: ${issues.join(', ')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      _saveServers(); // Save verification result
    });
  }

  // Helper method to determine the background color of a server location
  Color _getBackgroundColor(int index) {
    String status = _serverLocations[index]['status'];
    if (status == 'unverified') return const Color(0xFFCFD8DC); // Light grey
    if (status == 'ok') return const Color(0xFFC8E6C9); // Light green
    if (status == 'error') return const Color(0xFFF44336); // Red
    return Colors.white; // Default fallback
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return LayoutBuilder(
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
                      color: Colors.white, // Content panel background color
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section delimiter for "Server Locations"
                          SectionDelimiter(
                            title: 'Server Locations',
                            helpText:
                            'Here you can manage the locations of Apache servers. Add new servers by selecting a folder and remove servers no longer needed.',
                          ),
                          const SizedBox(height: 16),

                          // Buttons at the top
                          Row(
                            children: [
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: _addServerLocation,
                                  icon: Icon(Icons.add, color: const Color(0xFFECEFF1)), // Icon color updated
                                  label: const Text('Add Server Location'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF78909C), // Background color
                                    foregroundColor: const Color(0xFFECEFF1), // Text color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3.5), // Updated corner radius
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: _activeServerIndex != -1 ? _verifyActiveServer : null,
                                  icon: Icon(Icons.check_circle_outline, color: const Color(0xFFECEFF1)), // Icon color updated
                                  label: const Text('Verify Active Server'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF78909C), // Background color
                                    foregroundColor: const Color(0xFFECEFF1), // Text color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3.5), // Updated corner radius
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // List of server locations
                          if (_serverLocations.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _serverLocations.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  color: _getBackgroundColor(index),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(left:16, right: 12), // Match right padding with help icon
                                    title: Text(
                                      _serverLocations[index]['path'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: index == _activeServerIndex ? FontWeight.bold : FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Remove',
                                      onPressed: () => _removeServerLocation(index),
                                    ),
                                    onTap: () => _setActiveServer(index), // Set active server
                                  ),
                                );
                              },
                            )
                          else
                            const Text(
                              'No server locations defined yet. Add a new one to get started!',
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
    );
  }
}
