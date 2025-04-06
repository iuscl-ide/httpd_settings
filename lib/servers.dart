import 'package:flutter/material.dart';

class ServersTreeView extends StatefulWidget {
  final String selectedOption;
  final String? selectedTreeViewItem;
  final ValueChanged<String> onItemSelected;

  const ServersTreeView({
    super.key,
    required this.selectedOption,
    required this.onItemSelected,
    required this.selectedTreeViewItem,
  });

  @override
  ServersTreeViewState createState() => ServersTreeViewState();
}

class ServersTreeViewState extends State<ServersTreeView> {
  bool _isServersExpanded = true; // Controls expansion of "httpd Servers"
  String? _selectedChild; // Tracks the selected child item

  @override
  Widget build(BuildContext context) {
    if (widget.selectedOption == 'Servers') {
      return Container(
        color: const Color(0xFFECEFF1), // TreeView background color
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // Removes horizontal lines after child items
          ),
          child: ListView(
            children: [
              ExpansionTile(
                title: const Text(
                  'httpd Servers', // Updated label
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263238),
                  ),
                ),
                initiallyExpanded: _isServersExpanded,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _isServersExpanded = isExpanded;
                  });
                },
                iconColor: const Color(0xFF263238), // Matches the root item text color
                collapsedIconColor: const Color(0xFF263238), // Same for collapsed state
                trailing: Icon(
                  _isServersExpanded
                      ? Icons.arrow_drop_up // Upward triangle
                      : Icons.arrow_drop_down, // Downward triangle
                  color: const Color(0xFF263238),
                ),
                children: [
                  _buildSelectableListTile(
                    title: 'Locations', // Renamed to plural
                    icon: Icons.folder, // Folder icon for file system location
                    isSelected: _selectedChild == 'Locations',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'Locations';
                      });
                      widget.onItemSelected('Locations');
                    },
                  ),
                  _buildSelectableListTile(
                    title: 'Server Info',
                    icon: Icons.info_outline, // Icon for Info
                    isSelected: widget.selectedTreeViewItem == 'Server Info',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'Server Info';
                      });
                      widget.onItemSelected('Server Info');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Center(
        child: Text(
          '${widget.selectedOption} TreeView Placeholder',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }
  }

  Widget _buildSelectableListTile({
    required String title,
    required IconData icon, // Added icon parameter
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true, // Makes the ListTile more compact vertically
      leading: Icon(icon, color: isSelected ? Colors.black : Colors.grey[600]), // Add the icon
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.grey[800],
        ),
      ),
      contentPadding: const EdgeInsets.only(left: 32.0), // Add indentation
      onTap: onTap,
    );
  }
}
