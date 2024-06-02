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
  void initState() {
    super.initState();
    _startListeningToLocation();
    _loadGeoJsonData();
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
    final url =
        'http://172.20.10.3:8080/geoserver/map/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=map%3Aamenity_school_Nouakchott_again&maxFeatures=50&outputFormat=application%2Fjson';

    try {
      final data = geoJsonData;

      if (data.isNotEmpty) {
        final features = data['features'];

        List<Marker> markers = [];
        for (var feature in features) {
          final geometry = feature['geometry'];
          if (geometry['type'] == 'MultiPolygon') {
            final coordinates = geometry['coordinates'][0][0];
            for (var coordinate in coordinates) {
              final point = LatLng(coordinate[1], coordinate[0]);
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
                    Icons.school,
                    color: Colors.red,
                    size: 20.0,
                  ),
                ),
              ));
            }
          }
        }

        setState(() {
          geoJsonMarkers = markers;
        });
      } else {
        print('Failed to load GeoJSON data. Status code: ');
      }
    } catch (e) {
      print('Error loading GeoJSON data: $e');
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
                  -15.965238), // Coordinates approximative de Nouakchott
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

Map<String, dynamic> geoJsonData = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.1",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9366764, 18.1162767],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021206",
        "osm_id": "229021206",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": "École primaire"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.2",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9291538, 18.1115568],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021207",
        "osm_id": "229021207",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.3",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9286371, 18.1112641],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021208",
        "osm_id": "229021208",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.4",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9307623, 18.1075977],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021214",
        "osm_id": "229021214",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.5",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9281815, 18.1023137],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021215",
        "osm_id": "229021215",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.6",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9334978, 18.0933378],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021218",
        "osm_id": "229021218",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.7",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9371281, 18.0838789],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021219",
        "osm_id": "229021219",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": "ÉCOLE FATIMA ZAHRA",
        "barrier": "wall",
        "name": "مدرسة الزعتر الابتدائية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.8",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.941411, 18.075611],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021221",
        "osm_id": "229021221",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.9",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9470958, 18.0837549],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021222",
        "osm_id": "229021222",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.10",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9388058, 18.126883],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122017",
        "osm_id": "229122017",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": "طريق صكوك",
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة ثانوية تيارت",
        "name:fr": "Lycée Teyaret",
        "barrier": null,
        "name": "مدرسة ثانوية تيارت"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.11",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9376071, 18.1259793],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122019",
        "osm_id": "229122019",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": "طريق صكوك",
        "addr:city": "نواكشوط",
        "name:ar": "كلية",
        "name:fr": "COLLEGE",
        "barrier": null,
        "name": "كلية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.12",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9306625, 18.1324426],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122021",
        "osm_id": "229122021",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.13",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9352265, 18.1329026],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122022",
        "osm_id": "229122022",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.14",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9381827, 18.1189317],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229228322",
        "osm_id": "229228322",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.15",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9408725, 18.1243051],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229228369",
        "osm_id": "229228369",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": "Mo-Fr 08:00-14:00",
        "name:en": "Primary School",
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة ابتدائية",
        "name:fr": null,
        "barrier": "wall",
        "name": "École Primaire"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.16",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9450573, 18.0420844],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232444",
        "osm_id": "229232444",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.17",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9341949, 18.0778079],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232449",
        "osm_id": "229232449",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.18",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9325524, 18.0723133],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232453",
        "osm_id": "229232453",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.19",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9266287, 18.0691952],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232454",
        "osm_id": "229232454",
        "osm_type": "way",
        "amenity": "school",
        "office": "educational_institution",
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "ثانوية بوحديده",
        "name:fr": "Lycée Bouhdida",
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.20",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9211395, 18.0748592],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232457",
        "osm_id": "229232457",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.21",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9135627, 18.0744322],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232459",
        "osm_id": "229232459",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": "wall",
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.22",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9334508, 18.1409849],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481330",
        "osm_id": "229481330",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.23",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9259132, 18.1381477],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481331",
        "osm_id": "229481331",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.24",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9142676, 18.1197363],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481332",
        "osm_id": "229481332",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.25",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9213689, 18.1129374],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481333",
        "osm_id": "229481333",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.26",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9045823, 18.0655595],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229838925",
        "osm_id": "229838925",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.27",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9036872, 18.0667225],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229838926",
        "osm_id": "229838926",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.28",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9208126, 18.0650381],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839702",
        "osm_id": "229839702",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.29",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9295284, 18.0619947],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839703",
        "osm_id": "229839703",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.30",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9352253, 18.0668509],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839722",
        "osm_id": "229839722",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.31",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9293426, 18.0666599],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230051572",
        "osm_id": "230051572",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.32",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9273626, 18.0991763],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230056952",
        "osm_id": "230056952",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.33",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9333449, 18.0997914],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230280332",
        "osm_id": "230280332",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.34",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9311879, 18.1414806],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230488585",
        "osm_id": "230488585",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.35",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9080806, 18.0734202],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230777723",
        "osm_id": "230777723",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.36",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8990647, 18.0628807],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278243",
        "osm_id": "231278243",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.37",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8991955, 18.0627058],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278244",
        "osm_id": "231278244",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.38",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8995772, 18.0638979],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278245",
        "osm_id": "231278245",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.39",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931045, 18.1251352],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231392093",
        "osm_id": "231392093",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "مدرسة ابتدائية",
        "name:fr": "École primaire",
        "barrier": null,
        "name": "مدرسة ابتدائية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.40",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931045, 18.1251352],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231392094",
        "osm_id": "231392094",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.41",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8969698, 18.0685211],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231490639",
        "osm_id": "231490639",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.42",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9098312, 18.1412086],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231520010",
        "osm_id": "231520010",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.43",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9094976, 18.1201135],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231520458",
        "osm_id": "231520458",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.44",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9193068, 18.1092319],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231622335",
        "osm_id": "231622335",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.45",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9238777, 18.122189],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231658738",
        "osm_id": "231658738",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.46",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9299603, 18.124366],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231658773",
        "osm_id": "231658773",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.47",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9079077, 18.1321178],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231666545",
        "osm_id": "231666545",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.48",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931899, 18.0313997],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231978097",
        "osm_id": "231978097",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.49",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9250392, 18.0336273],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231978098",
        "osm_id": "231978098",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.50",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.915344, 18.1490497],
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w236838484",
        "osm_id": "236838484",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة الإمام البخاري",
        "name:fr": "Ecole El Imame Elboukhari",
        "barrier": null,
        "name": "مدرسة الإمام البخاري"
      }
    }
  ],
  "totalFeatures": 62,
  "numberMatched": 62,
  "numberReturned": 50,
  "timeStamp": "2024-06-01T15:18:32.945Z",
  "crs": {
    "type": "name",
    "properties": {"name": "urn:ogc:def:crs:EPSG::4326"}
  }
};
