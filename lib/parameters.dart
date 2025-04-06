import 'package:flutter/material.dart';

class ParametersTreeView extends StatefulWidget {
  final String selectedOption;
  final String? selectedTreeViewItem;
  final ValueChanged<String> onItemSelected;

  const ParametersTreeView({
    super.key,
    required this.selectedOption,
    required this.onItemSelected,
    required this.selectedTreeViewItem,
  });

  @override
  ParametersTreeViewState createState() => ParametersTreeViewState();
}

class ParametersTreeViewState extends State<ParametersTreeView> {
  bool _isExpanded = true; // Controls expansion of "Configuration Parameters"
  String? _selectedChild; // Tracks the selected child item

  @override
  Widget build(BuildContext context) {
    if (widget.selectedOption == 'Parameters') {
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
                  'Configuration Parameters', // Root menu
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263238),
                  ),
                ),
                initiallyExpanded: _isExpanded,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _isExpanded = isExpanded;
                  });
                },
                iconColor: const Color(0xFF263238),
                collapsedIconColor: const Color(0xFF263238),
                trailing: Icon(
                  _isExpanded
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: const Color(0xFF263238),
                ),
                children: [
                  _buildSelectableListTile(
                    title: 'SRVROOT',
                    icon: Icons.folder_open,
                    isSelected: widget.selectedTreeViewItem == 'SRVROOT',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'SRVROOT';
                      });
                      widget.onItemSelected('SRVROOT');
                    },
                  ),
                  _buildSelectableListTile(
                    title: 'Ports',
                    icon: Icons.swap_horiz,
                    isSelected: _selectedChild == 'Ports',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'Ports';
                      });
                      widget.onItemSelected('Ports');
                    },
                  ),
                  _buildSelectableListTile(
                    title: 'Virtual Hosts',
                    icon: Icons.cloud, // You can pick a different icon if you want
                    isSelected: _selectedChild == 'VirtualHosts',
                    onTap: () {
                      setState(() {
                        _selectedChild = 'VirtualHosts';
                      });
                      widget.onItemSelected('VirtualHosts');
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
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: isSelected ? Colors.black : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.grey[800],
        ),
      ),
      contentPadding: const EdgeInsets.only(left: 32.0),
      onTap: onTap,
    );
  }
}
