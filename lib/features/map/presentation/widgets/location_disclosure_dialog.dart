import 'package:flutter/material.dart';

class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Access Required'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This app collects location data to display your current position on the map and find nearby bus stops.',
            ),
            SizedBox(height: 12),
            Text(
              'This data is used only when the app is in use and is not shared with third parties.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'You can still use the search feature without location access.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // User declines
          child: const Text('No Thanks'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true), // User agrees
          child: const Text('Agree & Continue'),
        ),
      ],
    );
  }
}
