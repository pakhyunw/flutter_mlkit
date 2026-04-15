import 'dart:core';

class GS1Parser {
  static const String gs = '\x1D'; // ASCII 29

  // GS1 Application Identifiers (AI) mapping: AI -> {name, length, fixed}
  static const Map<String, _GS1AIDef> _gs1AIs = {
    '00': _GS1AIDef('SSCC', 18, true),
    '01': _GS1AIDef('GTIN', 14, true),
    '10': _GS1AIDef('BATCH/LOT', 20, false),
    '11': _GS1AIDef('PROD DATE', 6, true),
    '13': _GS1AIDef('PACK DATE', 6, true),
    '15': _GS1AIDef('BEST BEFORE', 6, true),
    '17': _GS1AIDef('EXPIRY', 6, true),
    '21': _GS1AIDef('SERIAL', 20, false),
    '310': _GS1AIDef('NET WEIGHT (kg)', 6, true), // 310n
    '311': _GS1AIDef('LENGTH (m)', 6, true), // 311n
    '312': _GS1AIDef('WIDTH (m)', 6, true), // 312n
    '313': _GS1AIDef('HEIGHT (m)', 6, true), // 313n
    '314': _GS1AIDef('AREA (m2)', 6, true), // 314n
    '315': _GS1AIDef('VOLUME (l)', 6, true), // 315n
    '316': _GS1AIDef('VOLUME (m3)', 6, true), // 316n
    '330': _GS1AIDef('GROSS WEIGHT (kg)', 6, true), // 330n
    '37': _GS1AIDef('COUNT', 8, false),
    '400': _GS1AIDef('ORDER NUMBER', 30, false),
    '410': _GS1AIDef('SHIP TO LOC', 13, true),
    '420': _GS1AIDef('SHIP TO POST', 20, false),
    '90': _GS1AIDef('INTERNAL', 30, false),
    '91': _GS1AIDef('INTERNAL', 30, false),
    '92': _GS1AIDef('INTERNAL', 30, false),
    '93': _GS1AIDef('INTERNAL', 30, false),
    '94': _GS1AIDef('INTERNAL', 30, false),
    '95': _GS1AIDef('INTERNAL', 30, false),
    '96': _GS1AIDef('INTERNAL', 30, false),
    '97': _GS1AIDef('INTERNAL', 30, false),
    '98': _GS1AIDef('INTERNAL', 30, false),
    '99': _GS1AIDef('INTERNAL', 30, false),
  };

  static Map<String, dynamic> parse(String barcode) {
    Map<String, dynamic> results = {};
    String data = barcode.trim();

    // 1. Remove Symbology Identifiers (e.g., ]C1, ]d2) and leading GS (ASCII 29)
    String workingData = data;
    if (workingData.startsWith(']C1')) workingData = workingData.substring(3);
    if (workingData.startsWith(']d2')) workingData = workingData.substring(3);
    while (workingData.startsWith(gs)) {
      workingData = workingData.substring(1);
    }

    // 2. Try parsing as GS1 with AIs first
    int i = 0;
    bool aiMatched = false;
    while (i < workingData.length) {
      String? matchedAI;
      _GS1AIDef? aiDef;

      for (int aiLen = 4; aiLen >= 2; aiLen--) {
        if (i + aiLen <= workingData.length) {
          String aiCandidate = workingData.substring(i, i + aiLen);
          if (_gs1AIs.containsKey(aiCandidate)) {
            matchedAI = aiCandidate;
            aiDef = _gs1AIs[aiCandidate];
            break;
          }
          if (aiLen == 4) {
             String aiPrefix = workingData.substring(i, i + 3);
             if (_gs1AIs.containsKey(aiPrefix)) {
                matchedAI = workingData.substring(i, i + 4);
                aiDef = _gs1AIs[aiPrefix];
                break;
             }
          }
        }
      }

      if (matchedAI == null || aiDef == null) break;

      aiMatched = true;
      i += matchedAI.length;

      String value;
      if (aiDef.fixed) {
        int end = i + aiDef.length;
        if (end > workingData.length) end = workingData.length;
        value = workingData.substring(i, end);
        i = end;
      } else {
        int gsIndex = workingData.indexOf(gs, i);
        if (gsIndex == -1) {
          value = workingData.substring(i);
          i = workingData.length;
        } else {
          value = workingData.substring(i, gsIndex);
          i = gsIndex + 1;
        }
        if (value.length > aiDef.length) {
          value = value.substring(0, aiDef.length);
        }
      }

      if (['11', '13', '15', '17'].contains(matchedAI)) {
        value = _formatGS1Date(value);
      } else if (matchedAI == '01') {
        value = normalizeGTIN(value);
      } else if (matchedAI == '00') {
        value = value.padLeft(18, '0');
      }

      results[matchedAI] = value;
    }

    // 3. Fallback: If no AIs matched and it looks like a raw GTIN, treat as AI '01'
    if (!aiMatched && _isRawGTIN(data)) {
      results['01'] = normalizeGTIN(data);
    }

    return results;
  }

  static bool _isRawGTIN(String data) {
    if (data.isEmpty) return false;
    final RegExp gtinRegex = RegExp(r'^\d{8,14}$');
    if (!gtinRegex.hasMatch(data)) return false;
    // Check common GTIN lengths: 8 (EAN-8), 12 (UPC-A), 13 (EAN-13), 14 (ITF-14)
    return [8, 12, 13, 14].contains(data.length);
  }

  static String normalizeGTIN(String gtin) {
    // Standardize to 14 digits by padding with leading zeros
    return gtin.trim().padLeft(14, '0');
  }

  /// Converts YYMMDD to YYYY-MM-DD based on century logic.
  static String _formatGS1Date(String yymmdd) {
    if (yymmdd.length != 6) return yymmdd;
    
    int yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
    String mm = yymmdd.substring(2, 4);
    String dd = yymmdd.substring(4, 6);

    int currentYear = DateTime.now().year;
    int currentCentury = (currentYear ~/ 100) * 100;
    int currentYY = currentYear % 100;

    int diff = yy - currentYY;
    int year;

    if (diff >= 51 && diff <= 99) {
      year = currentCentury - 100 + yy;
    } else if (diff >= -99 && diff <= -50) {
      year = currentCentury + 100 + yy;
    } else {
      year = currentCentury + yy;
    }

    return '$year-$mm-$dd';
  }
}

class _GS1AIDef {
  final String name;
  final int length;
  final bool fixed;

  const _GS1AIDef(this.name, this.length, this.fixed);
}
