/// CSV for spreadsheets: `;` by default (what Excel in Spanish expects) and a
/// UTF-8 BOM so it opens accents right. Reading detects `;`, `,` or tab.
abstract final class Csv {
  static const bom = '﻿';

  /// The first characters that make a spreadsheet read a cell as a formula
  /// (OWASP CSV Injection): `=`, `+`, `-`, `@`, tab and carriage return.
  static const formulaTriggers = ['=', '+', '-', '@', '\t', '\r'];

  /// A plain number with an optional leading minus, in Spanish (`-1.234,56`)
  /// or English (`-1234.56`) notation. Nothing else fits, so it cannot hold a
  /// formula and stays a number in the spreadsheet.
  static final _plainNumber = RegExp(r'^-?\d+([.,]\d+)*$');

  /// [text] safe to open in a spreadsheet: a value that starts with a
  /// formula trigger gets a leading `'`, so Excel, LibreOffice and Google
  /// Sheets show it as text and never run it. Negative numbers such as
  /// `-150,00` are left as they are, so they still add up.
  static String neutralizeFormula(String text) {
    if (text.isEmpty || _plainNumber.hasMatch(text)) return text;
    return formulaTriggers.any(text.startsWith) ? "'$text" : text;
  }

  /// [text] as it was before [neutralizeFormula]: drops the `'` that the
  /// export puts before a formula trigger, so `'+5355551234` reads
  /// `+5355551234` again. A `'` before anything else is kept.
  static String restoreFormula(String text) {
    if (text.length > 1 && text.startsWith("'") && formulaTriggers.any(text.substring(1).startsWith)) {
      return text.substring(1);
    }
    return text;
  }

  /// One line per row, fields quoted when they hold the separator, quotes or
  /// line breaks. Every field goes through [neutralizeFormula] first.
  static String encode(List<List<String?>> rows, {String separator = ';'}) {
    String field(String? value) {
      final text = neutralizeFormula(value ?? '');
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
