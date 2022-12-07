// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:location_demo/constants.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({Key? key}) : super(key: key);

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();

  static const LatLng sourceLocation = LatLng(11.0318, 77.0188);
  static const LatLng endLocation = LatLng(11.0291, 76.9852);

  List<LatLng> polylineCoordinates = [];
  LocationData? currenLocation;

  bool locationFetched = false;

  late bool _serviceEnabled ;
  late PermissionStatus _permissionGranted;
  
  Location location = Location();

  BitmapDescriptor sourceIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor currentLocationIcon = BitmapDescriptor.defaultMarker;

  final remoteConfig = FirebaseRemoteConfig.instance;

  Future remoteConfiguration() async{
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
));
}

   getCurrentLocation() async {

      location.getLocation().then(
      (location) {
      currenLocation = location;
    });

    GoogleMapController googleMapController = await _controller.future;

  if(locationFetched == false){
   setState(() {
    locationFetched = true;
   });

    location.onLocationChanged.listen(
      (LocationData newLoc) {
        if(newLoc == currenLocation){

          FirebaseDatabase database;
          database = FirebaseDatabase.instance;
          database.setPersistenceEnabled(true);
          database.setPersistenceCacheSizeBytes(10000000);

          addLocationData(GetLocation(
            latitude: newLoc.latitude!, 
            longitude: newLoc.longitude!,
            time: DateTime.now(),
            altitude: newLoc.altitude!,
            speed: newLoc.speed!,
            heading: newLoc.heading!),
            );
          print('Latitude = ${newLoc.latitude}');
          print('Longitude = ${newLoc.longitude}');
        }

      googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            zoom: 13.5,
            target: LatLng(
              newLoc.latitude!, 
              newLoc.longitude!,
              ),
            ),
          ),
        );
    });
  }
}

  void getPolyPoints() async {

    PolylinePoints polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      google_api,
      PointLatLng(sourceLocation.latitude,sourceLocation.longitude), 
      PointLatLng(endLocation.latitude, endLocation.longitude),
      );

      if(result.points.isNotEmpty){
        polylineCoordinates = [];
        result.points.forEach((PointLatLng point) {
          return polylineCoordinates.add(LatLng(point.latitude, point.longitude));
         });
      }
  }

  void setCustomMarkerIcon(){
    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "assets/Pin_source.png",).then((icon) {
      sourceIcon = icon;
    });

    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "assets/Pin_destination.png").then((icon) {
      destinationIcon = icon;
    });

    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, "assets/Badge.png").then((icon) {
      currentLocationIcon = icon;
    });
  }

  void autoRunning()async{

  //   _serviceEnabled = await location.serviceEnabled();
  //   if (!_serviceEnabled) {
  //   _serviceEnabled = await location.requestService();
  //   if (!_serviceEnabled) {
  //   return;
  //   }
  // }

    const time = Duration(seconds:10);
    Timer.periodic(time, (Timer t) => {
    getCurrentLocation(),
    getPolyPoints(),
    setCustomMarkerIcon(),
    print('after some delay'),
  });
  }

  @override
  void initState() {
    // FirebaseCrashlytics.instance.crash();
    getCurrentLocation();
    getPolyPoints();
    setCustomMarkerIcon();
    autoRunning();
    remoteConfiguration();
    super.initState();
  }

  Future addLocationData(GetLocation getLocation) async{
    
    final userLocation = FirebaseFirestore.instance.collection('testing').doc(); 
    
    final json = getLocation.toJson();

    await userLocation.set(json);

  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text('Tracking'),
        ),
        body: currenLocation == null ? 
        Center(
          child: Center(
            child: Column(
              children: const <Widget>[
                CircularProgressIndicator(),
                Text('Loading'),
              ],
            ),
          ),
          ) :
        GoogleMap(
          rotateGesturesEnabled : true,
          scrollGesturesEnabled : true,
          zoomControlsEnabled : true,
          zoomGesturesEnabled : true,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                currenLocation!.latitude!, 
                currenLocation!.longitude!
                ),
                zoom: 14,
              ),
              polylines: {
                Polyline(polylineId: PolylineId("route"),
                points: polylineCoordinates,
                color: Colors.blue,
                width: 6,
                ),
              },
            markers: {
              Marker(
                markerId: MarkerId("currentLocation"),
                icon: currentLocationIcon,
                position: LatLng(currenLocation!.latitude!, currenLocation!.longitude!),
                infoWindow: InfoWindow(
                  title: currenLocation.toString(),
                  snippet: 'my current location'
                ),
              ),
              Marker(
                markerId: MarkerId("source"),
                icon: sourceIcon,
                position: sourceLocation,
              ),
              Marker(
                markerId: MarkerId("destination"),
                icon: destinationIcon,
                position: endLocation,
              ),
            },
            onMapCreated: (mapController) {
              _controller.complete(mapController);
              },
      ),
      // Text("$currenLocation")
    );
  }
}

////////// models
class GetLocation{

  final double latitude;
  final double longitude;
  final DateTime time;
  final double altitude;
  final double speed;
  final double heading;//Heading is the horizontal direction of travel of this device, in degrees

  GetLocation({
    required this.latitude,
    required this.longitude,
    required this.time,
    required this.altitude,
    required this.speed,
    required this.heading,
    });

  Map<String, dynamic> toJson() => {
    'longitude' : longitude,
    'latitude' : latitude,
    'time' : time,
    'altitude' : altitude,
    'speed' : speed,
    'heading' : heading,
  };
}

// void autoRunning()async{
//     _serviceEnabled = await location.serviceEnabled();
//     if(!_serviceEnabled){
//       location.requestService();
//     }else{
//     const time = Duration(seconds:10);
//     Timer.periodic(time, (Timer t) => {
//     getCurrentLocation(),
//     getPolyPoints(),
//     setCustomMarkerIcon(),
//     print('after some delay'),
//   });
//     }
//   }