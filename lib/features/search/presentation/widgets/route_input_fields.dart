import 'package:flutter/material.dart';

class RouteInputFields extends StatelessWidget {
  final TextEditingController departController;
  final TextEditingController arriveeController;
  final VoidCallback onSearch;
  final Future<void> Function() onUseCurrentLocation;

  const RouteInputFields({
    super.key,
    required this.departController,
    required this.arriveeController,
    required this.onSearch,
    required this.onUseCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: departController,
          decoration: InputDecoration(
            labelText: 'Départ',
            prefixIcon: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: onUseCurrentLocation,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: arriveeController,
          decoration: InputDecoration(
            labelText: 'Arrivée',
            prefixIcon: const Icon(Icons.place),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => onSearch(),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text("Chercher un itinéraire"),
          onPressed: onSearch,
        )
      ],
    );
  }
}
