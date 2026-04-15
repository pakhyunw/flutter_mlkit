import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_mlkit/flutter_mlkit.dart';
import 'package:flutter_mlkit/gs1_parser.dart'; // 정규화 함수 사용을 위해 임포트

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

  // 사용자님의 원본 DB (13자리, 14자리 등이 섞여 있을 수 있음)
  final Map<String, Map<String, dynamic>> _rawBarcodeDb = {
    '8806489022715': {'name': 'Shin Ramyun', 'price': '1,200 KRW'}, // 13자리
    '08806555000326': {'name': 'Coke 500ml', 'price': '2,000 KRW'}, // 14자리
  };

  // 통합 관리를 위해 14자리로 정규화된 DB (내부 매칭용)
  late Map<String, Map<String, dynamic>> _normalizedDb;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 혹은 데이터 로딩 시 한 번만 정규화하면 관리가 편합니다.
    _normalizedDb = _rawBarcodeDb.map(
      (key, value) => MapEntry(GS1Parser.normalizeGTIN(key), value)
    );
  }

  void _openScanner(BuildContext context, ScanMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerView(
          mode: mode,
          barcodeMapList: _normalizedDb, // 정규화된 DB 전달
          onComplete: (results) {
            setState(() {
              _lastScanResult = results.map((r) => r.toString()).join('\n---\n');
            });
            if (mode == ScanMode.single) {
               Navigator.pop(context);
            }
          },
          overlayWidgetBuilder: (parsedData, isTarget) {
            final String? gtin = parsedData['01'];
            final String? sscc = parsedData['00'];
            final String batch = parsedData['10'] ?? '-';
            final String expiry = parsedData['17'] ?? '-';

            // Custom UI
            Color bgColor = Colors.black87;
            String statusText = "SCANNED";
            IconData icon = Icons.check_circle_outline;

            if (mode == ScanMode.find) {
              bgColor = isTarget ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);
              statusText = isTarget ? "✅ MATCHED" : "❌ MISMATCH";
              icon = isTarget ? Icons.verified : Icons.error_outline;
            }

            // 제품 정보 찾기: 이미 정규화된 _normalizedDb에서 gtin(14자리)으로 바로 조회
            final productInfo = gtin != null ? _normalizedDb[gtin] : null;

            return Container(
              width: 220,
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
                  if (gtin != null) 
                    Text("GTIN: $gtin", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (sscc != null)
                    Text("SSCC: $sscc", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  
                  Text("LOT: $batch", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Text("EXP: $expiry", style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
                  
                  if (productInfo != null) ...[
                    SizedBox(height: 5),
                    Text("Product: ${productInfo['name']}", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
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
              _buildModeButton(context, "OCR Integrated Mode (바코드+OCR)", ScanMode.ocr, Colors.redAccent),
              _buildModeButton(context, "OCR Only Mode (OCR 단독 스캔)", ScanMode.ocrOnly, Colors.blueGrey),
              
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
