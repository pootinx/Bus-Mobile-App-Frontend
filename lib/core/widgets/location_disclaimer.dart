import 'package:flutter/material.dart';

class LocationDisclaimer extends StatelessWidget {
  final String text;

  const LocationDisclaimer({
    super.key,
    this.text = 'Activez la géolocalisation pour des informations précises sur votre trajet',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Orange 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)), // Orange 200
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFFFB8C00)), // Orange 700
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
