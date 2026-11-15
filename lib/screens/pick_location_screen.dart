import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;

  final osm.MapController _osmController = osm.MapController();
  bool _osmReady = false;

  static const LatLng _defaultLocation = LatLng(
    10.762622,
    106.660172,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _osmController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLatLng;
      });

      if (kIsWeb) {
        if (_osmReady) _osmController.move(_toOsm(currentLatLng), 16);
      } else {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(currentLatLng, 16),
        );
      }
    } catch (_) {
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
    });
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, _selectedLocation);
    }
  }

  static ll.LatLng _toOsm(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn vị trí điểm danh")),
      body: kIsWeb ? _buildOsmMap() : _buildGoogleMap(),
      floatingActionButton: FloatingActionButton(
        onPressed: _confirmLocation,
        child: const Icon(Icons.check),
      ),
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _defaultLocation,
        zoom: 14,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onTap: _onMapTap,
      markers: _selectedLocation == null
          ? {}
          : {
              Marker(
                markerId: const MarkerId("selected"),
                position: _selectedLocation!,
              ),
            },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  Widget _buildOsmMap() {
    final selected = _selectedLocation;

    return Stack(
      children: [
        osm.FlutterMap(
          mapController: _osmController,
          options: osm.MapOptions(
            initialCenter: _toOsm(selected ?? _defaultLocation),
            initialZoom: selected == null ? 14 : 16,
            interactionOptions: const osm.InteractionOptions(
              flags: osm.InteractiveFlag.all & ~osm.InteractiveFlag.rotate,
            ),
            onTap: (_, point) =>
                _onMapTap(LatLng(point.latitude, point.longitude)),
            onMapReady: () {
              _osmReady = true;
              final current = _selectedLocation;
              if (current != null) _osmController.move(_toOsm(current), 16);
            },
          ),
          children: [
            osm.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app_diem_danh',
              maxNativeZoom: 19,
            ),
            if (selected != null)
              osm.MarkerLayer(
                markers: [
                  osm.Marker(
                    point: _toOsm(selected),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 44,
                    ),
                  ),
                ],
              ),
            const osm.SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
              alignment: Alignment.bottomLeft,
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'pick_location_my_location',
            tooltip: 'Vị trí của tôi',
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
