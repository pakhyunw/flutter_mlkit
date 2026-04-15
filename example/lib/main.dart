import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_mlkit/flutter_mlkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String _lastScanResult = "No data";

  // Dummy DB for Find Mode (Key: GTIN(01))
  final Map<int, Map<String, dynamic>> _targetBarcodeDb = {
    8806489022715: {'name': 'Shin Ramyun', 'price': '1,200 KRW'},
    8806555000326: {'name': 'Coke 500ml', 'price': '2,000 KRW'},
  };

  void _openScanner(BuildContext context, ScanMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerView(
          mode: mode,
          barcodeMapList: _targetBarcodeDb,
          onComplete: (results) {
            setState(() {
              _lastScanResult = results.map((r) => r.toString()).join('\n---\n');
            });
            if (mode != ScanMode.continuous) {
               Navigator.pop(context);
            }
          },
          overlayWidgetBuilder: (parsedData, isTarget) {
            final gtin = parsedData['01'] ?? 'No GTIN';
            final batch = parsedData['10'] ?? 'No Batch';
            final expiry = parsedData['17'] ?? 'No Expiry';

            // Custom UI based on mode and target status
            Color bgColor = Colors.black87;
            String statusText = "SCANNED";
            IconData icon = Icons.check_circle_outline;

            if (mode == ScanMode.find) {
              bgColor = isTarget ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);
              statusText = isTarget ? "✅ MATCHED" : "❌ MISMATCH";
              icon = isTarget ? Icons.verified : Icons.error_outline;
            }

            int gtinInt = int.parse(gtin);

            return Container(
              width: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text(statusText, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Divider(color: Colors.white24),
                  Text("GTIN: $gtin", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("LOT: $batch", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Text("EXP: $expiry", style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
                  if (isTarget || _targetBarcodeDb.containsKey(gtinInt)) ...[
                    SizedBox(height: 5),
                    Text("Product: ${_targetBarcodeDb[gtinInt]!['name']}", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AR GS1 Scanner Demo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeButton(context, "Single Mode (단일 스캔)", ScanMode.single, Colors.blue),
              _buildModeButton(context, "Continuous Mode (연속 스캔)", ScanMode.continuous, Colors.green),
              _buildModeButton(context, "Find Mode (바코드 찾기)", ScanMode.find, Colors.orange),
              _buildModeButton(context, "Multi Scan Mode (멀티 스캔)", ScanMode.multi, Colors.purple),
              
              SizedBox(height: 30),
              Text("Last Scan Result:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                margin: EdgeInsets.only(top:10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Text(_lastScanResult, style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),

              SizedBox(height: 50),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Container(
                          height: 400,
                          child: FlutterMlkit.scalableOCR(
                            getScannedText: (text) => print("OCR: $text"),
                            languageScript: LanguageScript.korean,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text("OCR Scanner (Original)"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(BuildContext context, String label, ScanMode mode, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _openScanner(context, mode),
        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

extension on EdgeInsets {
  static EdgeInsets top(double value) => EdgeInsets.only(top: value);
}
