import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// The apps are Spanish only.
abstract final class OttosLocalization {
  static const locale = Locale('es');

  static const supportedLocales = [locale];

  /// Spanish only. The `Global*Localizations` delegates choose the language at run time, so every language Flutter
  /// ships (about 80) went into the build; these build the Spanish classes directly (REQ-022 OPT-F1).
  static const delegates = <LocalizationsDelegate<dynamic>>[_Material(), _Widgets(), _Cupertino()];

  /// Loads the date formats used by `Formatters` and by [delegates]. Call before `runApp`.
  static Future<void> initialize() => initializeDateFormatting(_es);
}

const _es = 'es';

class _Material extends LocalizationsDelegate<MaterialLocalizations> {
  const _Material();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _es;

  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(
    MaterialLocalizationEs(
      fullYearFormat: DateFormat.y(_es),
      compactDateFormat: DateFormat.yMd(_es),
      shortDateFormat: DateFormat.yMMMd(_es),
      mediumDateFormat: DateFormat.MMMEd(_es),
      longDateFormat: DateFormat.yMMMMEEEEd(_es),
      yearMonthFormat: DateFormat.yMMMM(_es),
      shortMonthDayFormat: DateFormat.MMMd(_es),
      decimalFormat: NumberFormat.decimalPattern(_es),
      twoDigitZeroPaddedFormat: NumberFormat('00', _es),
    ),
  );

  @override
  bool shouldReload(_Material old) => false;
}

class _Widgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _Widgets();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _es;

  @override
  Future<WidgetsLocalizations> load(Locale locale) => SynchronousFuture(const WidgetsLocalizationEs());

  @override
  bool shouldReload(_Widgets old) => false;
}

class _Cupertino extends LocalizationsDelegate<CupertinoLocalizations> {
  const _Cupertino();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _es;

  @override
  Future<CupertinoLocalizations> load(Locale locale) => SynchronousFuture(
    CupertinoLocalizationEs(
      fullYearFormat: DateFormat.y(_es),
      dayFormat: DateFormat.d(_es),
      weekdayFormat: DateFormat.E(_es),
      mediumDateFormat: DateFormat.MMMEd(_es),
      singleDigitHourFormat: DateFormat('HH', _es),
      singleDigitMinuteFormat: DateFormat.m(_es),
      doubleDigitMinuteFormat: DateFormat('mm', _es),
      singleDigitSecondFormat: DateFormat.s(_es),
      decimalFormat: NumberFormat.decimalPattern(_es),
    ),
  );

  @override
  bool shouldReload(_Cupertino old) => false;
}
