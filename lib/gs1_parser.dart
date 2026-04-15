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

  /// Parses a GS1 barcode string into a map of AI and their values.
  static Map<String, dynamic> parse(String barcode) {
    Map<String, dynamic> results = {};
    String data = barcode;

    // 1. Remove Symbology Identifiers (e.g., ]C1, ]d2) and leading GS (ASCII 29)
    if (data.startsWith(']C1')) data = data.substring(3);
    if (data.startsWith(']d2')) data = data.substring(3);
    while (data.startsWith(gs)) {
      data = data.substring(1);
    }

    int i = 0;
    while (i < data.length) {
      String? matchedAI;
      _GS1AIDef? aiDef;

      // 2. Dynamic AI matching: Try 4 digits -> 3 digits -> 2 digits
      for (int aiLen = 4; aiLen >= 2; aiLen--) {
        if (i + aiLen <= data.length) {
          String aiCandidate = data.substring(i, i + aiLen);
          if (_gs1AIs.containsKey(aiCandidate)) {
            matchedAI = aiCandidate;
            aiDef = _gs1AIs[aiCandidate];
            break;
          }
          // Special case for AI 310n, 330n etc (last digit is decimal position)
          if (aiLen == 4) {
             String aiPrefix = data.substring(i, i + 3);
             if (_gs1AIs.containsKey(aiPrefix)) {
                matchedAI = data.substring(i, i + 4);
                aiDef = _gs1AIs[aiPrefix];
                break;
             }
          }
        }
      }

      if (matchedAI == null || aiDef == null) {
        // Unknown AI, stop parsing or skip
        break;
      }

      i += matchedAI.length;

      // 3. Variable/Fixed length processing
      String value;
      if (aiDef.fixed) {
        int end = i + aiDef.length;
        if (end > data.length) end = data.length;
        value = data.substring(i, end);
        i = end;
      } else {
        int gsIndex = data.indexOf(gs, i);
        if (gsIndex == -1) {
          value = data.substring(i);
          i = data.length;
        } else {
          value = data.substring(i, gsIndex);
          i = gsIndex + 1;
        }
        // Trim value if it exceeds max allowed length for the AI
        if (value.length > aiDef.length) {
          value = value.substring(0, aiDef.length);
        }
      }

      // 4. Date conversion (YYMMDD -> YYYY-MM-DD)
      if (['11', '13', '15', '17'].contains(matchedAI)) {
        value = _formatGS1Date(value);
      }

      results[matchedAI] = value;
    }

    return results;
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
