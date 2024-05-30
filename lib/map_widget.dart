import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Marker> geoJsonMarkers = [];
  List<LatLng> routePoints = [];
  final MapController _mapController = MapController();
  LatLng? userLocation;
  LatLng? selectedStation;
  String distance = '';

  @override
  void initState() async {
    super.initState();
    _startListeningToLocation();
    await _loadGeoJsonData();
  }

  void _startListeningToLocation() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        if (selectedStation != null) {
          _calculateRoute();
        }
      });
    });
  }

  Future<void> _loadGeoJsonData() async {
    final response = await http.get(Uri.parse(
        'http://172.20.10.3:8080/geoserver/map/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=map%3Aschool_Location_Nouakchott&maxFeatures=50&outputFormat=application%2Fjson'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'];

      List<Marker> markers = [];
      for (var feature in features) {
        final geometry = feature['geometry'];
        print(geometry);
        if (geometry['type'] == 'MultiPolygon') {
          final coordinates = geometry['coordinates'];
          final point = LatLng(coordinates[1], coordinates[0]);
          markers.add(Marker(
            width: 80.0,
            height: 80.0,
            point: point,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedStation = point;
                });
                _calculateRoute();
              },
              child: const Icon(
                Icons.local_gas_station,
                color: Colors.red,
                size: 20.0,
              ),
            ),
          ));
        }
      }

      setState(() {
        geoJsonMarkers = markers;
      });
    } else {
      throw Exception('Failed to load GeoJSON data');
    }
  }

  Future<void> _calculateRoute() async {
    if (userLocation == null || selectedStation == null) return;

    final apiKey = '5b3ce3597851110001cf62482a9fa2ebc51644fcbafae920e421322b';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${userLocation!.longitude},${userLocation!.latitude}&end=${selectedStation!.longitude},${selectedStation!.latitude}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['features'][0]['geometry']['coordinates'];
      final distanceInMeters =
          data['features'][0]['properties']['segments'][0]['distance'];

      List<LatLng> points = [];
      for (var coord in coordinates) {
        points.add(LatLng(coord[1], coord[0]));
      }

      setState(() {
        routePoints = points;
        distance = (distanceInMeters / 1000).toStringAsFixed(2) + ' km';
      });
    } else {
      throw Exception('Failed to load route data');
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.center, _mapController.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.center, _mapController.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stations Services à Nouakchott"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              onTap: (tapPosition, point) {
                print(point.longitude);
              },
              onMapEvent: (p0) {
                p0.camera;
              },
              initialCenter: const LatLng(18.079021,
                  -15.965238), // Coordonées approximatives de Nouakchott
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: geoJsonMarkers,
              ),
              if (userLocation !=
                  null) // Afficher le marqueur de la position de l'utilisateur
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: userLocation!,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40.0,
                      ),
                    )
                  ],
                ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
          if (selectedStation != null)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                color: const Color.fromRGBO(18, 45, 220, 0.5),
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Distance: $distance',
                  style: const TextStyle(fontSize: 16.0, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
