import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cafehop/models/cafe.dart';
import 'package:cafehop/themes.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

//real interactive map showing a cafe's location, replaces MapPlaceholder
//used on both CafeProfileScreen and BookingDetailScreen
class CafeMap extends StatefulWidget {
  final Cafe cafe;

  const CafeMap({super.key, required this.cafe});

  @override
  State<CafeMap> createState() => _CafeMapState();
}

class _CafeMapState extends State<CafeMap> {
  final MapController _mapController = MapController();

  late final Stream<LocationMarkerPosition?> _positionStream;

  @override
  void initState() {
    super.initState();

    //shares the same location stream with the marker and map
    _positionStream = LocationMarkerDataStreamFactory()
        .fromGeolocatorPositionStream()
        .asBroadcastStream();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitCafeAndUser();
    });
  }

  Future<void> _fitCafeAndUser() async {
    try {
      final position =
          await _positionStream.firstWhere((position) => position != null);

      if (!mounted || position == null) return;

      final cafePoint = LatLng(
        widget.cafe.latitude,
        widget.cafe.longitude,
      );

      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [
            cafePoint,
            position.latLng,
          ],
          padding: const EdgeInsets.all(40),
          maxZoom: 16,
        ),
      );
    } catch (e) {
      //if location is unavailable, the map just stays on the cafe
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(
      widget.cafe.latitude,
      widget.cafe.longitude,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: borderBlack, width: 1.8),
          borderRadius: BorderRadius.circular(10),
        ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
            //stops accidental map dragging when the parent screen scrolls
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            //free OSM tiles, no api key or billing, matches the spec's
            //ban on paid services like Google Maps
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cafehop.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _openInMaps(point),
                    child: Icon(
                      Icons.location_on,
                      color: darkBlue,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            CurrentLocationLayer(
              positionStream: _positionStream,
            ),
            //required by OpenStreetMap's usage policy, credits contributors
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //tapping the pin opens the device's own maps app for real turn by turn
  //directions, small bonus on top of just showing the pin
  Future<void> _openInMaps(LatLng point) async {
    final uri = Uri.parse(
      'geo:${point.latitude},${point.longitude}?q=${point.latitude},${point.longitude}(${Uri.encodeComponent(widget.cafe.name)})',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}