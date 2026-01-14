import 'package:flutter/material.dart';

class RouteInputFields extends StatefulWidget {
  final TextEditingController departController;
  final TextEditingController arriveeController;
  final VoidCallback onSearch;
  final Future<void> Function()? onUseCurrentLocation;

  const RouteInputFields({
    super.key,
    required this.departController,
    required this.arriveeController,
    required this.onSearch,
    this.onUseCurrentLocation,
  });

  @override
  State<RouteInputFields> createState() => _RouteInputFieldsState();
}

class _RouteInputFieldsState extends State<RouteInputFields> {
  final FocusNode _departFocusNode = FocusNode();

  void swapFields() {
    final temp = widget.departController.text;
    widget.departController.text = widget.arriveeController.text;
    widget.arriveeController.text = temp;
    widget.onSearch();
  }

@override
void initState() {
  super.initState();

  // Get current location as soon as the widget loads
  if (widget.onUseCurrentLocation != null) {
    widget.onUseCurrentLocation!().then((_) {
      // After location is set, perform the route search
      widget.onSearch();
    });
  }
}


  void _showDepartureSuggestions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text("Utiliser ma position actuelle"),
                onTap: () async {
                  Navigator.pop(context);
                  if (widget.onUseCurrentLocation != null) {
                    await widget.onUseCurrentLocation!();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_city),
                title: const Text("Gare centrale"),
                onTap: () {
                  widget.departController.text = "Gare centrale";
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text("Mon domicile"),
                onTap: () {
                  widget.departController.text = "Mon domicile";
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _departFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icons Column
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              SizedBox(height: 17),
              Icon(Icons.radio_button_unchecked, size: 20),
              SizedBox(height: 10),
              Icon(Icons.more_vert, size: 20),
              SizedBox(height: 10),
              Icon(Icons.location_on, size: 20, color: Colors.red),
            ],
          ),
          const SizedBox(width: 10),

          // Input Fields Column
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: widget.departController,
                  focusNode: _departFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Choisissez un point de départ...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.expand_more),
                      onPressed: () => _showDepartureSuggestions(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.arriveeController,
                  decoration: InputDecoration(
                    hintText: 'Choisissez une destination...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: widget.onSearch,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // const SizedBox(width: 10),

          // Swap Icon Column
          // Column(
          //   children: [
          //     const SizedBox(height: 40),
          //     GestureDetector(
          //       onTap: swapFields,
          //       child: const Icon(Icons.swap_vert, size: 24),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}
