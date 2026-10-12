/// CSV for spreadsheets: `;` by default (what Excel in Spanish expects) and a
/// UTF-8 BOM so it opens accents right. Reading detects `;`, `,` or tab.
abstract final class Csv {
  static const bom = '﻿';

  /// One line per row, fields quoted when they hold the separator, quotes or line breaks.
  static String encode(List<List<String?>> rows, {String separator = ';'}) {
    String field(String? value) {
      final text = value ?? '';
      final needsQuotes = text.contains(separator) || text.contains('"') || text.contains('\n') || text.contains('\r');
      return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
    }

    return '$bom${rows.map((row) => row.map(field).join(separator)).join('\r\n')}\r\n';
  }

  /// The rows of [text]; quoted fields may hold separators, quotes ("") and line breaks.
  static List<List<String>> decode(String text) {
    var source = text.startsWith(bom) ? text.substring(1) : text;
    source = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final separator = _detectSeparator(source);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == separator) {
        row.add(field.toString());
        field.clear();
      } else if (char == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    // Blank lines at the end (Excel adds some) are not rows. The ones in
    // between stay, so the row numbers match the spreadsheet's.
    while (rows.isNotEmpty && isBlank(rows.last)) {
      rows.removeLast();
    }
    return rows;
  }

  /// A row with nothing written in it.
  static bool isBlank(List<String> row) => row.every((value) => value.trim().isEmpty);

  /// The separator the header line uses most.
  static String _detectSeparator(String source) {
    final end = source.indexOf('\n');
    final header = end < 0 ? source : source.substring(0, end);
    const candidates = [';', ',', '\t'];
    var best = ';';
    var most = 0;
    for (final candidate in candidates) {
      final count = candidate.allMatches(header).length;
      if (count > most) {
        most = count;
        best = candidate;
      }
    }
    return best;
  }
}
