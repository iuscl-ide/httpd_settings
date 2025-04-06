import 'package:flutter/material.dart';

class ConfigurationsTreeView extends StatefulWidget {
  final String selectedOption;
  final String? selectedTreeViewItem;
  final ValueChanged<String> onItemSelected;

  const ConfigurationsTreeView({
    super.key,
    required this.selectedOption,
    required this.onItemSelected,
    required this.selectedTreeViewItem,
  });

  @override
  ConfigurationsTreeViewState createState() => ConfigurationsTreeViewState();
}

class ConfigurationsTreeViewState extends State<ConfigurationsTreeView> {
  bool _isConfigExpanded = true; // Controls expansion of "Server Configurations"
  String? _selectedChild; // Tracks the selected child item

  @override
  Widget build(BuildContext context) {
    if (widget.selectedOption == 'Configurations') {
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
                  'Server Configurations', // Root menu
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263238),
                  ),
                ),
                initiallyExpanded: _isConfigExpanded,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _isConfigExpanded = isExpanded;
                  });
                },
                iconColor: const Color(0xFF263238), // Matches the root item text color
                collapsedIconColor: const Color(0xFF263238), // Same for collapsed state
                trailing: Icon(
                  _isConfigExpanded
                      ? Icons.arrow_drop_up // Upward triangle
                      : Icons.arrow_drop_down, // Downward triangle
                  color: const Color(0xFF263238),
                ),
                children: [
                  _buildSelectableListTile(
                    title: 'Saved Configurations', // Updated name
                    icon: Icons.settings_suggest, // Save icon
                    isSelected: _selectedChild == 'Saved Configurations',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'Saved Configurations';
                      });
                      widget.onItemSelected('Saved Configurations');
                    },
                  ),
                  _buildSelectableListTile(
                    title: 'Configuration Info',
                    icon: Icons.info_outline,
                    isSelected: widget.selectedTreeViewItem == 'Configuration Info',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'Configuration Info';
                      });
                      widget.onItemSelected('Configuration Info');
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
