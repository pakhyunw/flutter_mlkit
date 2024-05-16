import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mlkit/flutter_mlkit.dart';
import 'package:flutter_mlkit/vision_detector_views/barcode_scanner_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google ML Kit Demo App'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ElevatedButton(
                      onPressed: () async {
                        var barcode = await FlutterMlkit.barcodeScan(context);
                        print(barcode);
                      },
                      child: Text('test')),
                  // ExpansionTile(
                  //   title: const Text('Vision APIs'),
                  //   children: [
                  //     CustomCard('Barcode Scanning', FlutterMlkit.barcodeScannerView),
                  //     CustomCard('Face Detection', FlutterMlkit.faceDetectorView),
                  //     CustomCard('Face Mesh Detection', FlutterMlkit.faceMeshDetectorView),
                  //     CustomCard('Image Labeling', FlutterMlkit.imageLabelView),
                  //     CustomCard('Object Detection', FlutterMlkit.objectDetectorView),
                  //     CustomCard('Text Recognition', FlutterMlkit.textRecognizerView),
                  //     CustomCard('Digital Ink Recognition', FlutterMlkit.digitalInkView),
                  //     CustomCard('Pose Detection', FlutterMlkit.poseDetectorView),
                  //     CustomCard('Selfie Segmentation', FlutterMlkit.selfieSegmenterView),
                  //   ],
                  // ),
                  // SizedBox(
                  //   height: 20,
                  // ),
                  // ExpansionTile(
                  //   title: const Text('Natural Language APIs'),
                  //   children: [
                  //     CustomCard('Language ID', FlutterMlkit.languageIdentifierView),
                  //     CustomCard(
                  //         'On-device Translation', FlutterMlkit.languageTranslatorView),
                  //     CustomCard('Smart Reply', FlutterMlkit.smartReplyView),
                  //     CustomCard('Entity Extraction', FlutterMlkit.entityExtractionView),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final String _label;
  final Widget _viewPage;
  final bool featureCompleted;

  const CustomCard(this._label, this._viewPage, {this.featureCompleted = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).primaryColor,
        title: Text(
          _label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('This feature has not been implemented yet')));
          } else {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => _viewPage));
          }
        },
      ),
    );
  }
}
