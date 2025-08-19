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
  Poi? _selectedPoi;

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

    try {
      // Use rectangular bounds for precise POI discovery
      final pois = await _poiService.fetchInBounds(
        north: bounds.north,
        south: bounds.south,
        east: bounds.east,
        west: bounds.west,
        maxResults: 20, // Limit to top 20 most interesting POIs
      );

      setState(() {
        _pois = pois;
        _isLoadingPois = false;
      });
    } catch (e) {
      setState(() => _isLoadingPois = false);
      // Handle error gracefully - could show a snackbar
      print('Error loading POIs: $e');
    }
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
          IgnorePointer(
            ignoring: _selectedPoi != null,
            child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                rotationThreshold: 30.0, // Higher threshold makes rotation require more deliberate gestures
                pinchZoomThreshold: 0.3, // Lower threshold makes zoom more responsive
              ),
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
                          width: _getMarkerSize(poi.interestLevel),
                          height: _getMarkerSize(poi.interestLevel),
                          point: LatLng(poi.lat, poi.lon),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPoi = poi;
                              });
                            },
                            child: _buildMarkerIcon(poi.interestLevel),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "reset_north",
                  onPressed: () => _mapController.rotate(0.0),
                  tooltip: 'Reset map orientation to north',
                  child: const Icon(Icons.navigation),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "my_location",
                  onPressed: _centerToCurrentLocation,
                  tooltip: 'Center to my location',
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          // POI details overlay
          if (_selectedPoi != null) ...[
            // Tap capture layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedPoi = null;
                  });
                },
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),
            // POI details panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.4,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) => Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 12,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: WikiPoiDetail(
                        poi: _selectedPoi!,
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _getMarkerSize(PoiInterestLevel level) {
    switch (level) {
      case PoiInterestLevel.high:
        return 50.0; // Larger for premium POIs
      case PoiInterestLevel.medium:
        return 40.0; // Standard size
      case PoiInterestLevel.low:
        return 30.0; // Smaller for low-interest POIs
    }
  }

  Widget _buildMarkerIcon(PoiInterestLevel level) {
    switch (level) {
      case PoiInterestLevel.high:
        // Premium golden star marker for high-interest POIs
        return const Icon(
          Icons.star,
          color: Colors.amber,
          size: 40,
          shadows: [
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 3.0,
              color: Color.fromARGB(100, 0, 0, 0),
            ),
          ],
        );
      case PoiInterestLevel.medium:
        // Standard blue marker for medium-interest POIs
        return const Icon(
          Icons.place,
          color: Colors.blue,
          size: 35,
          shadows: [
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 2.0,
              color: Color.fromARGB(100, 0, 0, 0),
            ),
          ],
        );
      case PoiInterestLevel.low:
        // Subtle gray marker for low-interest POIs
        return const Icon(
          Icons.location_on,
          color: Colors.grey,
          size: 25,
        );
    }
  }
}
