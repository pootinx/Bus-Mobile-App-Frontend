import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _busNameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _polylineController = TextEditingController();

  final TextEditingController _stopNameController = TextEditingController();
  final TextEditingController _stopLatController = TextEditingController();
  final TextEditingController _stopLonController = TextEditingController();

  final TextEditingController _startAddressController = TextEditingController();
  final TextEditingController _endAddressController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  final List<Map<String, dynamic>> _stops = [];
  final List<Map<String, dynamic>> _trips = [];

  void _addStop() {
    if (_stopNameController.text.trim().isNotEmpty &&
        _stopLatController.text.trim().isNotEmpty &&
        _stopLonController.text.trim().isNotEmpty) {
      setState(() {
        _stops.add({
          'name': _stopNameController.text.trim(),
          'lat': double.tryParse(_stopLatController.text.trim()) ?? 0.0,
          'lon': double.tryParse(_stopLonController.text.trim()) ?? 0.0,
        });
        _stopNameController.clear();
        _stopLatController.clear();
        _stopLonController.clear();
      });
    }
  }

  void _addTrip() {
    if (_startAddressController.text.trim().isNotEmpty &&
        _endAddressController.text.trim().isNotEmpty &&
        _startTimeController.text.trim().isNotEmpty &&
        _endTimeController.text.trim().isNotEmpty) {
      setState(() {
        _trips.add({
          'startAddress': _startAddressController.text.trim(),
          'endAddress': _endAddressController.text.trim(),
          'startTime': _startTimeController.text.trim(),
          'endTime': _endTimeController.text.trim(),
        });
        _startAddressController.clear();
        _endAddressController.clear();
        _startTimeController.clear();
        _endTimeController.clear();
      });
    }
  }

  Future<void> _saveBusRoute() async {
    final ville = _cityController.text.trim().toLowerCase();
    final lineName = _busNameController.text.trim();

    if (ville.isEmpty || lineName.isEmpty || _stops.isEmpty || _trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final busLine = {
      'route_name': lineName.toUpperCase(),
      'color': _colorController.text.trim().isNotEmpty ? _colorController.text.trim() : '#4285F4',
      'polyline': _polylineController.text.trim(),
      'stops': _stops,
      'trips': _trips,
    };

    try {
      // 🔄 Use random document ID for the bus line
      final newDocRef = FirebaseFirestore.instance.collection(ville).doc();
      await newDocRef.set(busLine);

      // ✅ Ensure city is added to 'cities' collection
      final cityRef = FirebaseFirestore.instance.collection('cities').doc(ville);
      final cityDoc = await cityRef.get();
      if (!cityDoc.exists) {
        await cityRef.set({'name': ville});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ligne "$lineName" ajoutée à "$ville"')),
      );

      _polylineController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      controller.text = time.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Ajouter une ligne de bus', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_cityController, 'Ville (ex: Tetouan)'),
            _buildTextField(_busNameController, 'Nom de la ligne de bus (ex: L1)'),
            _buildTextField(_colorController, 'Couleur hex (ex: #FF0000)'),
            _buildTextField(_polylineController, 'Polyline (encodée Google Maps)'),
            const SizedBox(height: 20),
            _buildSectionTitle('Ajouter un arrêt'),
            _buildTextField(_stopNameController, 'Nom de l\'arrêt'),
            _buildTextField(_stopLatController, 'Latitude', keyboardType: TextInputType.number),
            _buildTextField(_stopLonController, 'Longitude', keyboardType: TextInputType.number),
            _buildButton('Ajouter l\'arrêt', _addStop),
            _buildStopsList(),
            const SizedBox(height: 20),
            _buildSectionTitle('Ajouter un trajet'),
            _buildTextField(_startAddressController, 'Adresse de départ'),
            _buildTextField(_endAddressController, 'Adresse d\'arrivée'),
            _buildTimeField(_startTimeController, 'Heure de départ'),
            _buildTimeField(_endTimeController, 'Heure d\'arrivée'),
            _buildButton('Ajouter le trajet', _addTrip),
            _buildTripsList(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _saveBusRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enregistrer la Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTimeField(TextEditingController controller, String label) {
    return GestureDetector(
      onTap: () => _selectTime(context, controller),
      child: AbsorbPointer(
        child: _buildTextField(controller, label),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStopsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _stops.map((stop) {
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(stop['name']),
          subtitle: Text('Lat: ${stop['lat']}, Lon: ${stop['lon']}'),
        );
      }).toList(),
    );
  }

  Widget _buildTripsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _trips.map((trip) {
        return ListTile(
          leading: const Icon(Icons.directions_bus, color: Colors.green),
          title: Text('${trip['startAddress']} ➔ ${trip['endAddress']}'),
          subtitle: Text('Départ: ${trip['startTime']} | Arrivée: ${trip['endTime']}'),
        );
      }).toList(),
    );
  }
}
