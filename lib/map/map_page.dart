// lib/map/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';
import '../services/poi_service.dart';
import 'wiki_poi_detail.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Poi> _pois = [];
  final PoiService _poiService = PoiService();
  LatLng _mapCenter = const LatLng(32.0741, 34.7924); // fallback: Azrieli
  final MapController _mapController = MapController();
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isLoadingPois = false;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<LatLng?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _initMap() async {
    final location = await _getCurrentLocation();

    if (location != null) {
      _mapCenter = location;
      _mapController.move(location, 15);
    }

    await _loadPoisInView();
  }

  Future<void> _loadPoisInView() async {
    final now = DateTime.now();
    if (now.difference(_lastRequestTime).inSeconds < 2) return;
    _lastRequestTime = now;

    final bounds = _mapController.camera.visibleBounds;

    setState(() => _isLoadingPois = true);

    final centerLat = (bounds.north + bounds.south) / 2;
    final centerLon = (bounds.east + bounds.west) / 2;

    // approximate radius by vertical distance
    final distance = const Distance();
    final radius = (distance.as(
              LengthUnit.Meter,
              LatLng(bounds.north, centerLon),
              LatLng(bounds.south, centerLon),
            ) /
            2)
        .round();

    final pois = await _poiService.fetchNearby(centerLat, centerLon, radius: radius);

    setState(() {
      _pois = pois;
      _isLoadingPois = false;
    });
  }

  Future<void> _centerToCurrentLocation() async {
    final location = await _getCurrentLocation();
    if (location != null) {
      _mapController.move(location, 15);
      await _loadPoisInView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passear')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(),
              onMapReady: () => _loadPoisInView(),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) _loadPoisInView();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.passear',
              ),
              MarkerLayer(
                markers: _pois
                    .map((poi) => Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(poi.lat, poi.lon),
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => WikiPoiDetail(poi: poi),
                              );
                            },
                            child: const Icon(Icons.place, color: Colors.blue),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          if (_isLoadingPois)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centerToCurrentLocation,
              tooltip: 'Center to my location',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
