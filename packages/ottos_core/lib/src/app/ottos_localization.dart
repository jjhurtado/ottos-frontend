import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The apps are Spanish only.
abstract final class OttosLocalization {
  static const locale = Locale('es');

  static const supportedLocales = [locale];

  static const delegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Loads the date formats used by `Formatters`. Call before `runApp`.
  static Future<void> initialize() => initializeDateFormatting('es');
}
