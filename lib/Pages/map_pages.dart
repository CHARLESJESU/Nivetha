import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;

import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;

  const MapPage({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.address,
  }) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? currentPosition;
  GoogleMapController? _mapController;
  double? distance;
 String googleAPIKey ="AIzaSyD2edYZVpcriijRUyOPuj1fVU4icLgGt2M";
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getRoutePolyline();
  }
  Future<void> _getRoutePolyline() async {
    PolylinePoints polylinePoints = PolylinePoints();
    List<LatLng> polylineCoordinates = [];

    final origin = "${currentPosition!.latitude},${currentPosition!.longitude}";
    final destination = "${widget.latitude},${widget.longitude}";
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$googleAPIKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polyline = route['overview_polyline']['points'];

        polylineCoordinates = polylinePoints
            .decodePolyline(polyline)
            .map((e) => LatLng(e.latitude, e.longitude))
            .toList();

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId("route"),
            points: polylineCoordinates,
            width: 4,
            color: Colors.blue,
          ));
        });
      }
    } else {
      print("Failed to get directions");
    }
  }Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentPosition = position;
      distance = _calculateDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        widget.latitude,
        widget.longitude,
      );
    });

    // Now fetch the polyline
    await _getRoutePolyline();

    if (_mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          currentPosition!.latitude < widget.latitude
              ? currentPosition!.latitude
              : widget.latitude,
          currentPosition!.longitude < widget.longitude
              ? currentPosition!.longitude
              : widget.longitude,
        ),
        northeast: LatLng(
          currentPosition!.latitude > widget.latitude
              ? currentPosition!.latitude
              : widget.latitude,
          currentPosition!.longitude > widget.longitude
              ? currentPosition!.longitude
              : widget.longitude,
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin...
  }

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    CameraPosition initialPosition = CameraPosition(
      target: LatLng(widget.latitude, widget.longitude),
      zoom: 16,
    );

    Set<Marker> markers = {
      Marker(
        markerId: MarkerId("location"),
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(title: widget.address),
      ),
    };
    // Set<Polyline> polylines = {};
    //
    // if (currentPosition != null) {
    //   polylines.add(
    //     Polyline(
    //       polylineId: const PolylineId("route"),
    //       visible: true,
    //       points: [
    //         LatLng(currentPosition!.latitude, currentPosition!.longitude),
    //         LatLng(widget.latitude, widget.longitude),
    //       ],
    //       color: Colors.blue,
    //       width: 4,
    //     ),
    //   );
    // }

    if (currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId("you"),
          position:
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          infoWindow: InfoWindow(title: "You"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Location")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialPosition,
            markers: markers,
           polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (distance != null)
            Positioned(
              top: 46,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Distance: ${distance!.toStringAsFixed(2)} km",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
