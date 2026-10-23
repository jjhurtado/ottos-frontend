import 'package:intl/intl.dart';

import '../models/statistics.dart';
import '../utils/formatters.dart';

/// Texts of the reports and statistics, shared by the panel and the app.
abstract final class ReportTexts {
  // Monthly summary
  static const reports = 'Reportes';
  static const monthlyReport = 'Resumen mensual';
  static const previousMonth = 'Mes anterior';
  static const nextMonth = 'Mes siguiente';
  static const reportRemittances = 'Remesas';
  static const totalCollected = 'Total cobrado';
  static const totalCollectedHelp = 'Entregas: monto enviado + comisión, pagado por los remitentes';
  static const pickupsCollected = 'Recogido por los repartidores';
  static String pickupsHelp(int count, String fees) => '$count recogidas · $fees de comisiones';
  static String earningsHelp(String deliveries, String pickups, String rounding) =>
      'Entregas $deliveries · recogidas $pickups · además $rounding por redondeo al entregar';
  static const collectedOrPicked = 'Cobrado o recogido';
  static const totalDelivered = 'Total entregado';
  static const difference = 'Diferencia';
  static const differenceHelp = 'Cobrado − entregado, solo entregas';
  static const earnings = 'Ganancias (comisiones)';
  static const byCurrency = 'Entregas por moneda';
  static const byType = 'Por tipo';
  static const monthEndStatus = 'Estado al cierre del mes';
  static const sent = 'Enviado';
  static const fees = 'Comisiones';
  static const collected = 'Cobrado';
  static const delivered = 'Entregado';
  static String deliveredIn(String currency) => 'Entregado en $currency';
  static const completedLabel = 'Completadas';
  static const openLabel = 'Abiertas (pagadas o asignadas)';
  static const withIncidentLabel = 'Con incidencia';
  static const totalRow = 'Total';
  static const noSales = 'No hay remesas registradas este mes.';
  static String deliveriesAndPickups(int deliveries, int pickups) => '$deliveries entregas · $pickups recogidas';
  static const onTheHouseReport = 'Por la casa (comisiones no cobradas)';
  static String onTheHouseHelp(int count, String amount) =>
      '${count == 1 ? '1 entrega' : '$count entregas'} sin comisión · $amount enviados';
  static String reportPeriod(String from, String to, String currency) =>
      'Del $from al $to · hora de Cuba · importes en $currency';
  static String generatedOn(String when) => 'Generado el $when';
  static const deliveries = 'Entregas';
  static const pickups = 'Recogidas';

  /// "Octubre de 2026".
  static String monthTitle(DateTime month) {
    final text = DateFormat.yMMMM('es').format(month);
    return text[0].toUpperCase() + text.substring(1);
  }

  /// "octubre de 2026".
  static String monthLower(DateTime month) => DateFormat.yMMMM('es').format(month);

  // Export
  static const export = 'Exportar';
  static const exportSummaryPdf = 'Resumen general (PDF)';
  static const exportSummaryPdfHelp = 'Una página A4 con los totales del mes.';
  static const exportDetailPdf = 'Resumen a detalle (PDF)';
  static const exportDetailPdfHelp =
      'A4 horizontal: resumen y todas las remesas del mes, entregas, recogidas y anuladas aparte. Sin datos personales.';
  static const exportCsv = 'Remesas (CSV)';
  static const exportCsvHelp = 'Una fila por remesa del mes, anuladas incluidas y marcadas. Se abre en Excel.';
  static String summaryFileName(String month) => 'resumen-mensual-$month.pdf';
  static String detailFileName(String month) => 'resumen-a-detalle-$month.pdf';
  static String csvFileName(String month) => 'remesas-$month.csv';
  static const exportFailed = 'No se pudo preparar el archivo. Inténtalo de nuevo.';

  // The month's remittances
  static const monthRemittances = 'Remesas del mes';
  static String monthRemittancesHelp(String month) =>
      'Registradas en $month · sin datos personales: cada remesa se identifica por su código';
  static const searchCode = 'Buscar por código';
  static const type = 'Tipo';
  static const status = 'Estado';
  static const courier = 'Repartidor';
  static const all = 'Todos';
  static const withoutCourier = 'Sin asignar';
  static const onlyOnTheHouse = 'Solo por la casa';
  static const showVoided = 'Mostrar anuladas';
  static const filters = 'Filtros';
  static const filtersActive = 'Filtros (hay alguno puesto)';
  static const filtersHelp = 'Tipo, estado, repartidor, por la casa y anuladas';
  static const statusPaid = 'Pagada';
  static const statusAssigned = 'Asignada';
  static const statusCompleted = 'Completada';
  static const statusIncident = 'Con incidencia';
  static const voided = 'Anulada';
  static const code = 'Código';
  static const registered = 'Registrada';
  static const completed = 'Completada';
  static const municipality = 'Municipio';
  static const amount = 'Importe';
  static const fee = 'Comisión';
  static const toDeliver = 'A entregar';
  static const rate = 'Tasa';
  static const picked = 'Recogido';
  static const onTheHouseShort = 'casa';
  static const sortNewest = 'Ordenar de la más antigua a la más reciente';
  static const sortOldest = 'Ordenar de la más reciente a la más antigua';
  static const noRemittancesFound = 'Ninguna remesa coincide con los filtros.';
  static String remittancesCount(int count) => count == 1 ? '1 remesa' : '$count remesas';
  static String filteredTotalsNote(int voided) => voided == 0
      ? 'Totales de lo filtrado, sin anuladas'
      : 'Totales de lo filtrado, sin anuladas ($voided anuladas en la lista, aparte)';
  static String voidedOn(String date, String reason) => 'Anulada el $date · Motivo: $reason';
  static const tableHelp =
      'Importes en USD; «A entregar» en la moneda de entrega. Las anuladas salen en gris con los importes tachados y, '
      'debajo, la fecha y el motivo tal cual se escribió al anular.';
  static String pageOf(int first, int last, int total) => '$first–$last de $total';
  static const previousPage = 'Página anterior';
  static const nextPage = 'Página siguiente';

  /// A backend without the reports detail or the statistics (before the
  /// version that brings them) answers 404.
  static const notAvailableYet =
      'Esta sección todavía no está disponible: llegará cuando se actualice el servidor. El resto de la aplicación '
      'funciona como siempre.';

  // Statistics
  static const statistics = 'Estadísticas';
  static const periodCurrentMonth = 'Mes actual';
  static const periodPreviousMonth = 'Mes anterior';
  static const periodLastThreeMonths = 'Últimos 3 meses';
  static const periodCustom = 'Personalizado…';
  static String statisticsPeriod(String from, String to, String currency) =>
      'Del $from al $to · por fecha de registro · hora de Cuba · importes en $currency · sin anuladas';
  static const tooLongPeriod = 'Elige como mucho 366 días.';
  static String fewData(int count) =>
      'Este periodo lleva ${remittancesCount(count)}. Con tan pocos datos los gráficos dicen poco: las medias se marcan '
      'como «pocos datos» hasta tener ${Statistics.fewDataThreshold} remesas.';
  static const seePreviousMonth = 'Ver el mes anterior';
  static const fewDataChip = 'pocos datos';
  static const remittances = 'Remesas';
  static const collectedCard = 'Cobrado';
  static const collectedCardHelp = 'Entregas: enviado + comisión';
  static const earningsHelpShort = 'Entregas y recogidas';
  static const averageAmount = 'Importe medio';
  static const salesByWeek = 'Ventas por semana';
  static const salesByWeekHelp =
      'Semanas de lunes a domingo · mantener el puntero o el dedo sobre una barra muestra sus cifras';
  static const remittancesByWeek = 'Remesas por semana';
  static const weekCount = 'Número de remesas';
  static String weekCollected(String currency) => 'Cobrado ($currency)';
  static const salesByDay = 'Ventas por día de la semana';
  static const salesByDayHelp = 'Número de remesas registradas cada día de la semana en el periodo.';
  static const averageTitle = 'Importe medio por remesa';
  static String averageHelp(String pickups) =>
      'Monto enviado medio de las entregas (sin comisión).${pickups.isEmpty ? '' : ' Las recogidas, aparte: $pickups de media.'}';
  static String averageFewData(int deliveries) =>
      'Media de ${deliveries == 1 ? '1 entrega' : '$deliveries entregas'}. Sin comparación con el periodo anterior hasta tener '
      '${Statistics.fewDataThreshold} remesas.';
  static String comparison(String percent, bool up) => '${up ? '▲' : '▼'} $percent frente al periodo anterior';
  static const sameAsBefore = 'Igual que en el periodo anterior';
  static const weeklyEvolution = 'Evolución semanal';
  static const byMunicipality = 'Remesas por municipio';
  static const byMunicipalityHelp = 'Los 10 con más remesas; el resto, en «Otros»';
  static String others(int municipalities) =>
      'Otros (${municipalities == 1 ? '1 municipio' : '$municipalities municipios'})';
  static const onTheHouseTitle = 'Remesas por la casa';
  static const onTheHouseNone = 'Remesas por la casa: ninguna en este periodo';
  static String percentOfTotal(String percent) => '$percent del total';
  static const waivedFees = 'Comisión no cobrada';
  static const waivedFeesHelp = 'lo que se dejó de ganar';
  static const onTheHouseSentHelp = 'montos de esas entregas';
  static const month = 'Mes';
  static const week = 'Semana';
  static const onTheHouseTableHelp = 'Las cifras siguen contando en el resto de la página con comisión 0.';
  static String noDataFor(String chart) => '$chart: nada en este periodo';
  static const noDataHelp = 'Cuando el periodo tenga remesas, aquí se verá el gráfico.';
  static String weekTip(String label, int count) => 'Semana del $label: ${remittancesCount(count)}';
  static String weekCollectedTip(String label, String amount) => 'Semana del $label: $amount cobrados';
  static String incomplete(String text) => '$text (incompleta)';
  static String dayTip(String day, int count) => '$day: ${remittancesCount(count)}';

  static String dayShort(DayOfWeek day) => switch (day) {
    DayOfWeek.monday => 'Lun',
    DayOfWeek.tuesday => 'Mar',
    DayOfWeek.wednesday => 'Mié',
    DayOfWeek.thursday => 'Jue',
    DayOfWeek.friday => 'Vie',
    DayOfWeek.saturday => 'Sáb',
    DayOfWeek.sunday => 'Dom',
  };

  static String dayName(DayOfWeek day) => switch (day) {
    DayOfWeek.monday => 'Lunes',
    DayOfWeek.tuesday => 'Martes',
    DayOfWeek.wednesday => 'Miércoles',
    DayOfWeek.thursday => 'Jueves',
    DayOfWeek.friday => 'Viernes',
    DayOfWeek.saturday => 'Sábado',
    DayOfWeek.sunday => 'Domingo',
  };

  /// "4 oct 2026" for a plain date (no zone shift).
  static String date(DateTime? date) => date == null ? '' : DateFormat.yMMMd('es').format(date);

  /// "4 oct" for a plain date.
  static String shortDate(DateTime date) => DateFormat.MMMd('es').format(date);

  /// "4,2 %".
  static String percent(double value) =>
      '${NumberFormat.decimalPatternDigits(locale: 'es', decimalDigits: 1).format(value)} %';

  /// A money amount without its currency, Spanish separators.
  static String number(double value) => Formatters.money(value, null);

  /// A rate: "410" or "410,5".
  static String formatRate(double value) => NumberFormat('#,##0.####', 'es').format(value);
}
