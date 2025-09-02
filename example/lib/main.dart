import 'dart:async';
import 'dart:developer';

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

  String text = "";
  final controller = StreamController<String>.broadcast();

  void setText(value) {
    controller.add(value);
  }

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
                        await FlutterMlkit.barcodeScan(context,(value)=>print(value), isContinue: true, );
                      },
                      child: Text('QR Scan')),
                  ElevatedButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                              key: UniqueKey(),
                                child : SizedBox(
                                    height: MediaQuery.of(context).size.height / 2,
                                    width: MediaQuery.of(context).size.width * 0.9,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: <Widget>[
                                          FlutterMlkit.scalableOCR(
                                              paintboxCustom: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = 2.0
                                                ..color = Colors.amberAccent,
                                              boxHeight: MediaQuery.of(context).size.height / 4,
                                              roiBoxSize: Size(400,200),
                                              getRawData: (value) {
                                                inspect(value);
                                              },
                                              getScannedText: (value) {
                                                print(value);
                                              }),
                                          StreamBuilder<String>(
                                            stream: controller.stream,
                                            builder:
                                                (BuildContext context, AsyncSnapshot<String> snapshot) {
                                              return Result(
                                                  text: snapshot.data != null ? snapshot.data! : "");
                                            },
                                          )
                                        ],
                                      ),
                                    ))
                            );
                          }
                        );
                      },
                      child: Text('OCR')),
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

class Result extends StatelessWidget {
  const Result({
    Key? key,
    required this.text,
  }) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text("Readed text: $text");
  }
}