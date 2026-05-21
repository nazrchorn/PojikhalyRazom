import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location.dart';

class PickupDropoffLocationScreen extends StatefulWidget {
  final Location tripOrigin;
  final Location tripDestination;
  final Location? initialFocusLocation;
  final bool isPickup;
  final String defaultCity;
  final String apiKey;

  const PickupDropoffLocationScreen({
    super.key,
    required this.tripOrigin,
    required this.tripDestination,
    this.initialFocusLocation,
    required this.isPickup,
    required this.defaultCity,
    required this.apiKey,
  });

  @override
  State<PickupDropoffLocationScreen> createState() => _PickupDropoffLocationScreenState();
}

class _PickupDropoffLocationScreenState extends State<PickupDropoffLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final bool _isLoading = false;

  final Color primaryTurquoise = const Color(0xFF1F6F66);

  @override
  void initState() {
    super.initState();
    // For segment bookings, focus first on the selected stop city when it is known.
    final Location anchor = widget.initialFocusLocation ??
        (widget.isPickup ? widget.tripOrigin : widget.tripDestination);
    _selectedLocation = LatLng(anchor.lat, anchor.lng);
    _selectedAddress = widget.defaultCity.trim().isNotEmpty
        ? widget.defaultCity
        : anchor.city;
    _addressController.text = _selectedAddress ?? '';
  }

  Future<void> _confirmSelection() async {
    if (_selectedLocation == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Будь ласка, оберіть місцезнаходження')),
      );
      return;
    }

    Navigator.pop(context, {
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isPickup ? 'Місце посадки' : 'Місце висадження';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? LatLng(widget.tripOrigin.lat, widget.tripOrigin.lng),
              initialZoom: 13,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                  _selectedAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
                  _addressController.text = _selectedAddress ?? '';
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.pojikhaly_razom',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        widget.isPickup ? Icons.location_on : Icons.flag_circle,
                        color: primaryTurquoise,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Введіть адесу або натисніть на карті',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.location_on_outlined, color: primaryTurquoise, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (value) {
                  setState(() {
                    _selectedAddress = value;
                  });
                },
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTurquoise,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Підтвердити $title',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}



