// lib/map/map_page.dart
import 'dart:async';
// ignore: unused_import
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi.dart';
import '../models/route.dart';
import '../models/settings.dart';
import '../services/poi_service.dart';
import '../services/poi_search_service.dart';
import '../services/routing_service.dart';
import '../services/tts_service.dart';
import '../services/tts/tts_orchestrator.dart';
import '../services/settings_service.dart';
import '../settings/settings_page.dart';
import 'wiki_poi_detail.dart';

// Constants for search UI
const double _kSearchDropdownMaxHeight = 400.0;
const Duration _kSearchDebounceDelay = Duration(milliseconds: 500);
const int _kMinSearchCharacters = 2; // Minimum characters before triggering search
const int _kMaxSearchHistory = 10; // Maximum number of search history items to keep
const String _kSearchHistoryKey = 'search_history'; // SharedPreferences key

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Poi> _pois = [];
  final PoiService _poiService = PoiService();
  final RoutingService _routingService = RoutingService();
  final SettingsService _settingsService = SettingsService.instance;
  TtsService? _ttsService;
  LatLng _mapCenter = const LatLng(32.0741, 34.7924); // fallback: Azrieli
  final MapController _mapController = MapController();
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isLoadingPois = false;
  Poi? _selectedPoi;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _mapRotation = 0.0; // Track current map rotation for compass display
  bool _hasPerformedInitialLoad =
      false; // Flag to ensure initial load happens only once

  // Provider settings
  MapProvider _mapProvider = MapProvider.openStreetMap;

  // User location tracking
  LatLng? _userLocation;
  double? _userHeading; // Direction user is facing in degrees (0 = North)
  StreamSubscription<Position>? _locationSubscription;

  // Navigation state
  NavigationRoute? _currentRoute;
  LatLng? _destinationMarker;
  bool _isLoadingRoute = false;
  int _currentInstructionIndex = 0;
  bool _voiceGuidanceEnabled = true; // Cache for performance

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<PoiSearchResult> _searchSuggestions = [];
  bool _isLoadingSearchSuggestions = false;
  Timer? _searchDebounceTimer;
  List<String> _searchHistory = []; // Recent search queries

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initMap();
    _startLocationTracking();
    _loadVoiceGuidanceSetting();
    _loadSearchHistory();
  }

  Future<void> _initializeTts() async {
    final settings = await _settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _ttsService = TtsOrchestrator(
          openAiApiKey: settings.llmApiKey,
          ttsVoice: settings.ttsVoice,
          forceOfflineMode: settings.ttsOfflineMode,
        );
      });
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _ttsService?.dispose();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceGuidanceSetting() async {
    final settings = await _settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _voiceGuidanceEnabled = settings.voiceGuidanceEnabled;
        _mapProvider = settings.mapProvider;
      });
      // Update routing and POI providers (outside setState since they don't affect UI state)
      _routingService.updateProvider(settings.routingProvider);
      _poiService.updateProvider(settings.poiProvider);
    }
  }

  /// Load search history from SharedPreferences
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_kSearchHistoryKey) ?? [];
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Error loading search history: $e');
    }
  }

  /// Save search query to history
  Future<void> _saveToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    try {
      // Remove if already exists (to move it to top)
      _searchHistory.remove(query);
      // Add to beginning
      _searchHistory.insert(0, query);
      // Limit to max items
      if (_searchHistory.length > _kMaxSearchHistory) {
        _searchHistory = _searchHistory.sublist(0, _kMaxSearchHistory);
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, _searchHistory);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  /// Clear all search history
  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSearchHistoryKey);
      if (mounted) {
        setState(() {
          _searchHistory = [];
        });
      }
    } catch (e) {
      debugPrint('Error clearing search history: $e');
    }
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

    // POI loading will be triggered by onPositionChanged callback
    // which is more reliable than onMapReady on iOS
    // Also schedule a fallback load using post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleInitialPoiLoad();
    });
  }

  void _startLocationTracking() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Start listening to location updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          // Heading is available on some devices (compass direction)
          _userHeading = position.heading;
        });
        // Update navigation progress if navigating
        _updateNavigationProgress();
      },
    );
  }

  Future<void> _loadPoisInView({bool isInitialLoad = false}) async {
    final now = DateTime.now();
    if (now.difference(_lastRequestTime).inSeconds < 2) return;
    _lastRequestTime = now;

    try {
      final bounds = _mapController.camera.visibleBounds;

      if (isInitialLoad) {
        debugPrint(
          'POI: Got map bounds - N:${bounds.north}, S:${bounds.south}, E:${bounds.east}, W:${bounds.west}',
        );
        _hasPerformedInitialLoad = true;
      }

      // Validate bounds are reasonable (not NaN or infinite)
      if (bounds.north.isNaN ||
          bounds.south.isNaN ||
          bounds.east.isNaN ||
          bounds.west.isNaN ||
          bounds.north <= bounds.south ||
          bounds.east <= bounds.west) {
        if (isInitialLoad) {
          // Reset flag to allow retry
          _hasPerformedInitialLoad = false;
          // Retry after a longer delay for initial load
          debugPrint('Invalid bounds on initial load, retrying...');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (!mounted) return; // Check if widget is still mounted
          return _loadPoisInView(isInitialLoad: true);
        }
        debugPrint('Invalid map bounds, skipping POI load');
        return;
      }

      if (!mounted) return; // Check before setState
      setState(() => _isLoadingPois = true);

      // Use rectangular bounds for precise POI discovery
      final pois = await _poiService.fetchInBounds(
        north: bounds.north,
        south: bounds.south,
        east: bounds.east,
        west: bounds.west,
        // maxResults will be determined by settings
      );

      if (!mounted) return; // Check before setState
      setState(() {
        _pois = pois;
        _isLoadingPois = false;
      });

      if (isInitialLoad) {
        debugPrint(
          'POI: Successfully loaded ${pois.length} POIs on initial load',
        );
      }
    } catch (e) {
      if (!mounted) return; // Check before setState
      setState(() => _isLoadingPois = false);

      if (isInitialLoad) {
        // Reset flag to allow retry
        _hasPerformedInitialLoad = false;
        // For initial load failures, retry once after a delay
        debugPrint('Initial POI load failed, retrying: $e');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return; // Check if widget is still mounted
        return _loadPoisInView(isInitialLoad: true);
      }

      // Handle error gracefully - could show a snackbar
      debugPrint('Error loading POIs: $e');
    }
  }

  Future<void> _loadPoisInViewWithDelay() async {
    // Add a delay to ensure map is fully stabilized on iOS
    debugPrint('POI: onMapReady triggered, waiting for map stabilization...');
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return; // Check if widget is still mounted
    debugPrint('POI: Starting initial POI load after delay');
    return _loadPoisInView(isInitialLoad: true);
  }

  Future<void> _scheduleInitialPoiLoad() async {
    if (_hasPerformedInitialLoad) return;

    debugPrint('POI: Scheduling initial POI load...');
    // Wait longer on iOS to ensure map is fully initialized
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return; // Check if widget is still mounted

    if (!_hasPerformedInitialLoad) {
      debugPrint('POI: Attempting fallback initial POI load');
      await _loadPoisInView(isInitialLoad: true);
    }
  }

  void _onMapPositionChanged(dynamic position, bool hasGesture) {
    // For the initial load, use the first position change event
    if (!_hasPerformedInitialLoad && !hasGesture) {
      _hasPerformedInitialLoad = true;
      debugPrint(
        'POI: First position change detected, starting initial POI load',
      );
      // Small delay to ensure bounds are stable, then load POIs
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        if (mounted) {
          // Check if widget is still mounted
          _loadPoisInView(isInitialLoad: true);
        }
      });
      return;
    }

    // For subsequent loads triggered by user gestures
    if (hasGesture) {
      _loadPoisInView();
    }

    // Track map rotation for compass display
    final newRotation = position.rotation ?? 0.0;
    if (newRotation != _mapRotation) {
      if (mounted) {
        // Check if widget is still mounted before setState
        setState(() {
          _mapRotation = newRotation;
        });
      }
    }
  }

  void _showPoiDetails(Poi poi) {
    setState(() {
      _selectedPoi = poi;
    });
    // Check if controller is attached before animating
    // This prevents crashes when POI is selected before sheet is built
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _hidePoiDetails() {
    setState(() {
      _selectedPoi = null;
    });
  }

  /// Perform POI search and show results
  Future<void> _performSearch(String query, {bool showSheet = true}) async {
    final trimmedQuery = query.trim();
    
    // Clear suggestions if query is too short
    if (trimmedQuery.isEmpty || trimmedQuery.length < _kMinSearchCharacters) {
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
          _isLoadingSearchSuggestions = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingSearchSuggestions = true;
      });
    }

    try {
      // Create search service with language detection
      final searchService = PoiSearchService(
        lang: _detectLanguage(trimmedQuery),
      );

      // Get current map bounds
      final bounds = _mapController.camera.visibleBounds;

      // Perform search with context
      final results = await searchService.searchPois(
        query: trimmedQuery,
        userLocation: _userLocation,
        mapBounds: MapBounds(
          north: bounds.north,
          south: bounds.south,
          east: bounds.east,
          west: bounds.west,
        ),
        limit: 10,
      );

      if (!mounted) return;

      setState(() {
        _searchSuggestions = results;
        _isLoadingSearchSuggestions = false;
      });

      if (results.isEmpty && showSheet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No results found for "$trimmedQuery"\n'
              'Try a different search term or check spelling',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Show search results in a bottom sheet only if requested
      if (showSheet && results.isNotEmpty) {
        _showSearchResults(results);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSearchSuggestions = false;
        _searchSuggestions = [];
      });
      if (showSheet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Detect language from query text to use appropriate Wikipedia
  String _detectLanguage(String query) {
    // Check for Hebrew characters
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(query)) {
      return 'he';
    }
    // Check for Russian characters
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(query)) {
      return 'ru';
    }
    // Check for Arabic characters
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(query)) {
      return 'ar';
    }
    // Check for Chinese characters
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(query)) {
      return 'zh';
    }
    // Check for Japanese characters
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(query)) {
      return 'ja';
    }
    // Default to English
    return 'en';
  }

  /// Build the search dropdown content with history and suggestions
  Widget _buildSearchDropdownContent() {
    final query = _searchController.text;
    final showHistory = query.isEmpty || query.length < _kMinSearchCharacters;

    // Show history when query is empty or too short
    if (showHistory && _searchHistory.isNotEmpty) {
      return ListView(
        shrinkWrap: true,
        children: [
          // History header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                TextButton(
                  onPressed: _clearSearchHistory,
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          // History items
          ..._searchHistory.map((historyQuery) {
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(historyQuery),
              onTap: () {
                // Fill search field with history item and trigger search
                _searchController.text = historyQuery;
                _performSearch(historyQuery, showSheet: false);
              },
            );
          }),
        ],
      );
    }

    // Show search suggestions
    if (_searchSuggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No results found'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _searchSuggestions.length,
      itemBuilder: (context, index) {
        final result = _searchSuggestions[index];
        return ListTile(
          leading: Icon(
            _getCategoryIcon(result.poi.category),
            color: _getInterestLevelColor(result.poi.interestLevel),
          ),
          title: Text(result.poi.name),
          subtitle: result.poi.description.isNotEmpty
              ? Text(
                  result.poi.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Text(
            '${result.relevanceScore.toStringAsFixed(0)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            // Save to history
            _saveToSearchHistory(result.poi.name);
            
            // Close search mode
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchSuggestions = [];
              
              // Add the searched POI to the map's POI list if not already present
              // This ensures it shows as a marker on the map
              final poiExists = _pois.any((p) => p.id == result.poi.id);
              if (!poiExists) {
                _pois = [..._pois, result.poi];
              }
            });
            // Navigate to POI
            _mapController.move(
              LatLng(result.poi.lat, result.poi.lon),
              16,
            );
            // Show POI details
            _showPoiDetails(result.poi);
          },
        );
      },
    );
  }

  /// Show search results in a bottom sheet
  void _showSearchResults(List<PoiSearchResult> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Search Results (${results.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final poi = result.poi;
                      return ListTile(
                        leading: Icon(
                          _getCategoryIcon(poi.category),
                          color: _getInterestLevelColor(poi.interestLevel),
                        ),
                        title: Text(
                          poi.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (poi.description.isNotEmpty)
                              Text(
                                poi.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Relevance: ${result.relevanceScore.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToSearchResult(poi);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Navigate to a search result POI
  void _navigateToSearchResult(Poi poi) {
    // Save to search history
    _saveToSearchHistory(poi.name);
    
    // Move map to the POI location
    _mapController.move(
      LatLng(poi.lat, poi.lon),
      16, // Zoom level
    );

    // Show POI details and add to map's POI list
    setState(() {
      _selectedPoi = poi;
      _isSearching = false;
      _searchController.clear();
      
      // Add the searched POI to the map's POI list if not already present
      // This ensures it shows as a marker on the map
      final poiExists = _pois.any((p) => p.id == poi.id);
      if (!poiExists) {
        _pois = [..._pois, poi];
      }
    });

    // Animate the sheet to show details
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_sheetController.isAttached && mounted) {
        _sheetController.animateTo(
          0.4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Get icon for POI category
  IconData _getCategoryIcon(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return Icons.museum;
      case PoiCategory.historicalSite:
        return Icons.castle;
      case PoiCategory.landmark:
        return Icons.landscape;
      case PoiCategory.religiousSite:
        return Icons.church;
      case PoiCategory.park:
        return Icons.park;
      case PoiCategory.monument:
        return Icons.account_balance;
      case PoiCategory.university:
        return Icons.school;
      case PoiCategory.theater:
        return Icons.theater_comedy;
      case PoiCategory.gallery:
        return Icons.palette;
      case PoiCategory.architecture:
        return Icons.architecture;
      case PoiCategory.generic:
        return Icons.place;
    }
  }

  /// Get color for interest level
  Color _getInterestLevelColor(PoiInterestLevel level) {
    switch (level) {
      case PoiInterestLevel.high:
        return Colors.amber;
      case PoiInterestLevel.medium:
        return Colors.blue;
      case PoiInterestLevel.low:
        return Colors.grey;
    }
  }

  Future<void> _startNavigation(LatLng destination) async {
    if (_userLocation == null) {
      // Show error message if user location is not available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location not available. Please try again.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _destinationMarker = destination;
    });

    try {
      final route = await _routingService.getRoute(
        start: _userLocation!,
        destination: destination,
      );

      if (mounted) {
        setState(() {
          _currentRoute = route;
          _isLoadingRoute = false;
          _currentInstructionIndex = 0;
        });

        // Fit the map to show the entire route
        if (route != null && route.waypoints.isNotEmpty) {
          _fitMapToRoute(route);
          // Announce route summary if voice guidance is enabled
          if (_voiceGuidanceEnabled && _ttsService != null) {
            _ttsService!.speak(
              'Route calculated. Distance: ${route.formattedDistance}. '
              'Estimated time: ${route.formattedDuration}',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to calculate route: $e')),
        );
      }
    }
  }

  void _stopNavigation() {
    setState(() {
      _currentRoute = null;
      _destinationMarker = null;
      _currentInstructionIndex = 0;
    });
  }

  void _updateNavigationProgress() {
    if (_currentRoute == null || _userLocation == null) return;

    // Find the closest instruction point
    for (int i = _currentInstructionIndex;
        i < _currentRoute!.instructions.length;
        i++) {
      final instruction = _currentRoute!.instructions[i];
      final distance = const Distance().distance(
        _userLocation!,
        instruction.location,
      );

      // If we're within 50 meters of the next instruction, announce it
      if (distance < 50 && i > _currentInstructionIndex) {
        setState(() {
          _currentInstructionIndex = i;
        });
        // Announce the instruction via TTS
        _announceInstruction(instruction, distance);
        break;
      }
    }
  }

  void _announceInstruction(RouteInstruction instruction, double distance) {
    // Check if voice guidance is enabled (using cached value for performance)
    if (!_voiceGuidanceEnabled || _ttsService == null) {
      return; // Voice guidance is disabled, skip announcement
    }

    String announcement;
    if (instruction.type == 10) {
      // Arrival instruction
      announcement = 'You have arrived at your destination';
    } else if (distance < 20) {
      // Very close
      announcement = instruction.text;
    } else {
      // Still approaching
      announcement =
          'In ${instruction.formattedDistance}, ${instruction.text.toLowerCase()}';
    }
    _ttsService!.speak(announcement);
  }

  void _showCustomDestinationDialog(LatLng destination) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigate to this location?'),
        content: Text(
          'Latitude: ${destination.latitude.toStringAsFixed(5)}\n'
          'Longitude: ${destination.longitude.toStringAsFixed(5)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _startNavigation(destination);
            },
            icon: const Icon(Icons.directions_walk),
            label: const Text('Navigate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _fitMapToRoute(NavigationRoute route) {
    if (route.waypoints.isEmpty) return;

    // Calculate bounds to fit all waypoints
    double minLat = route.waypoints.first.latitude;
    double maxLat = route.waypoints.first.latitude;
    double minLon = route.waypoints.first.longitude;
    double maxLon = route.waypoints.first.longitude;

    for (final point in route.waypoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));

    // Fit the map to the bounds with some padding
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _centerToCurrentLocation() async {
    final location = await _getCurrentLocation();
    if (location != null) {
      // Preserve the current zoom level when centering to location
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(location, currentZoom);
      await _loadPoisInView();
    }
  }

  /// Get tile layer configuration based on selected map provider
  TileLayer _getTileLayer() {
    switch (_mapProvider) {
      case MapProvider.openStreetMap:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.passear',
        );
      case MapProvider.googleMaps:
        // Note: Google Maps tiles require an API key
        // This is a placeholder - in production, you would use google_maps_flutter plugin
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.passear',
          // TODO: Implement Google Maps tiles integration
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search attractions...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                ),
                style: TextStyle(color: colorScheme.onPrimary),
                onChanged: (query) {
                  // Cancel previous timer
                  _searchDebounceTimer?.cancel();
                  
                  // Debounce search to avoid excessive API calls
                  _searchDebounceTimer = Timer(_kSearchDebounceDelay, () {
                    _performSearch(query, showSheet: false);
                  });
                },
                onSubmitted: (query) {
                  _searchDebounceTimer?.cancel();
                  if (query.isNotEmpty) {
                    _performSearch(query, showSheet: true);
                  }
                },
              )
            : const Text('Passear'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
              onPressed: () {
                _searchDebounceTimer?.cancel();
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchSuggestions = [];
                  _isLoadingSearchSuggestions = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search attractions',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              // Reload POIs and voice guidance setting after settings change
              _loadPoisInView();
              _loadVoiceGuidanceSetting();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace:
                    true, // Enforce gesture race so rotation requires explicit intent
                rotationThreshold:
                    15.0, // Threshold keeps deliberate rotations possible
                pinchZoomThreshold: 0.3,
              ),
              onMapReady: () {
                debugPrint('POI: onMapReady callback fired');
                if (!_hasPerformedInitialLoad) {
                  _loadPoisInViewWithDelay();
                }
              },
              onPositionChanged: _onMapPositionChanged,
              onLongPress: (tapPosition, point) {
                // Long press to set custom destination
                _showCustomDestinationDialog(point);
              },
            ),
            children: [
              _getTileLayer(),
              MarkerLayer(
                markers: _pois
                    .map(
                      (poi) => Marker(
                        width: _getMarkerSize(poi.interestLevel),
                        height: _getMarkerSize(poi.interestLevel),
                        point: LatLng(poi.lat, poi.lon),
                        child: GestureDetector(
                          onTap: () => _showPoiDetails(poi),
                          child: _buildMarkerIcon(poi.interestLevel),
                        ),
                      ),
                    )
                    .toList(),
              ),
              // Route polyline
              if (_currentRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentRoute!.waypoints,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Destination marker
              if (_destinationMarker != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _destinationMarker!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                        shadows: [
                          Shadow(
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                            color: Color.fromARGB(100, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              // User location marker
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 60,
                      height: 60,
                      point: _userLocation!,
                      child: _buildUserLocationMarker(),
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoadingPois)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          // Search suggestions dropdown
          if (_isSearching && (_searchSuggestions.isNotEmpty || _isLoadingSearchSuggestions || _searchHistory.isNotEmpty))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: _kSearchDropdownMaxHeight),
                  color: Theme.of(context).colorScheme.surface,
                  child: _isLoadingSearchSuggestions
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _buildSearchDropdownContent(),
                ),
              ),
            ),
          // Route loading indicator
          if (_isLoadingRoute)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Calculating route...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Route summary display
          if (_currentRoute != null && !_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentRoute!.formattedDistance,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'About ${_currentRoute!.formattedDuration}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _voiceGuidanceEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _voiceGuidanceEnabled = !_voiceGuidanceEnabled;
                          });
                          _settingsService.updateVoiceGuidanceEnabled(
                            _voiceGuidanceEnabled,
                          );
                        },
                        tooltip: _voiceGuidanceEnabled
                            ? 'Voice guidance on'
                            : 'Voice guidance off',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _stopNavigation,
                        tooltip: 'Stop navigation',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Dimming overlay when POI sheet is visible
          if (_selectedPoi != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _hidePoiDetails,
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          // POI Details Sheet
          if (_selectedPoi != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: DraggableScrollableSheet(
                key: ValueKey(_selectedPoi?.id),
                controller: _sheetController,
                initialChildSize: 0.4,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (context, scrollController) => Material(
                  elevation: 12,
                  color: Theme.of(context).colorScheme.surface,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: SafeArea(
                      top: false,
                      child: WikiPoiDetail(
                        poi: _selectedPoi!,
                        scrollController: scrollController,
                        onNavigate: (destination) {
                          _hidePoiDetails();
                          _startNavigation(destination);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Navigation instruction display
          if (_currentRoute != null &&
              _currentInstructionIndex < _currentRoute!.instructions.length)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getInstructionIcon(
                              _currentRoute!
                                  .instructions[_currentInstructionIndex].type,
                            ),
                            color: Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentRoute!
                                      .instructions[_currentInstructionIndex]
                                      .text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_currentRoute!
                                        .instructions[_currentInstructionIndex]
                                        .distanceMeters >
                                    0)
                                  Text(
                                    'In ${_currentRoute!.instructions[_currentInstructionIndex].formattedDistance}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentInstructionIndex + 1) /
                            _currentRoute!.instructions.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  onPressed: () {
                    _mapController.rotate(0.0);
                    setState(() {
                      _mapRotation = 0.0;
                    });
                  },
                  tooltip: 'Reset map orientation to north',
                  child: AnimatedRotation(
                    turns: _mapRotation /
                        360.0, // Rotate with map to show orientation
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(Icons.navigation),
                  ),
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
        ],
      ),
    );
  }

  IconData _getInstructionIcon(int type) {
    // OpenRouteService instruction types
    switch (type) {
      case 0: // Turn left
        return Icons.turn_left;
      case 1: // Turn right
        return Icons.turn_right;
      case 2: // Turn sharp left
        return Icons.turn_sharp_left;
      case 3: // Turn sharp right
        return Icons.turn_sharp_right;
      case 4: // Turn slight left
        return Icons.turn_slight_left;
      case 5: // Turn slight right
        return Icons.turn_slight_right;
      case 6: // Continue straight
        return Icons.straight;
      case 7: // Enter roundabout
        return Icons.roundabout_right;
      case 10: // Arrive at destination
        return Icons.flag;
      default:
        return Icons.navigation;
    }
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
        return const Icon(Icons.location_on, color: Colors.grey, size: 25);
    }
  }

  Widget _buildUserLocationMarker() {
    // If heading is available, show Google Maps-style directional indicator
    if (_userHeading != null && _userHeading! >= 0) {
      return Transform.rotate(
        angle: _userHeading! * pi / 180, // Convert degrees to radians
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Directional cone (like Google Maps flashlight beam)
            CustomPaint(
              size: const Size(60, 60),
              painter: _DirectionalConePainter(),
            ),
            // White circle border
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
            // Small white dot in center
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // If no heading, show simple circular marker
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.2),
          ),
        ),
        // Middle circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.3),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        // Inner blue dot
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

// Custom painter for directional cone (Google Maps style)
class _DirectionalConePainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = ui.PaintingStyle.fill;

    final path = ui.Path();
    final center = ui.Offset(size.width / 2, size.height / 2);

    // Create cone shape pointing upward (will be rotated by Transform.rotate)
    // Cone angle: 45 degrees on each side (90 degrees total)
    final coneLength = size.height * 0.8;

    // Start from center
    path.moveTo(center.dx, center.dy);

    // Left edge of cone
    final leftX = center.dx - coneLength * 0.5;
    final leftY = center.dy - coneLength;
    path.lineTo(leftX, leftY);

    // Arc at the top
    final radius = coneLength * 0.5;
    path.arcToPoint(
      ui.Offset(center.dx + coneLength * 0.5, center.dy - coneLength),
      radius: ui.Radius.circular(radius),
      clockwise: true,
    );

    // Right edge back to center
    path.lineTo(center.dx, center.dy);
    path.close();

    canvas.drawPath(path, paint);

    // Add a subtle border to the cone
    final borderPaint = ui.Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
