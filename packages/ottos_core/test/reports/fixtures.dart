/// A month that adds up: the detail's rows sum to the monthly report, as the
/// backend promises (contracts monthly-report.md › Detalle and statistics.md).
library;

const reasonWithSeparator = 'Registrada dos veces; la buena es "OT-K7Q2MA"';

final detailJson = <String, dynamic>{
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'generatedAt': '2026-11-01T13:05:00Z',
  'businessCurrency': 'USD',
  'counts': {
    'lines': 5,
    'voided': 1,
    'total': 4,
    'delivery': 3,
    'pickup': 1,
    'completed': 2,
    'open': 2,
    'withIncident': 1,
  },
  'remittances': [
    _row(
      'OT-K7Q2MA',
      createdAt: '2026-10-01T16:30:00Z',
      status: 'DELIVERED',
      completedAt: '2026-10-02T18:00:00Z',
      courier: 'Pedro Díaz',
      amount: 100,
      fee: 10,
      toDeliver: 41000,
      delivered: 100,
    ),
    _row(
      'OT-P3X8RA',
      type: 'PICKUP',
      createdAt: '2026-10-03T14:00:00Z',
      status: 'DELIVERED',
      completedAt: '2026-10-04T15:00:00Z',
      fromBusiness: true,
      municipality: ('2303', 'Centro Habana'),
      amount: 200,
      fee: 20,
      toDeliver: 82000,
      collected: 200,
    ),
    _row(
      'OT-R9T4BW',
      createdAt: '2026-10-05T12:00:00Z',
      status: 'ASSIGNED',
      courier: 'Ana Pérez',
      amount: 237,
      fee: 0,
      toDeliver: 97150,
      delivered: 236.95,
      onTheHouse: 23.70,
      incident: true,
    ),
    _row(
      'OT-F9V3GA',
      createdAt: '2026-10-11T19:20:00Z',
      status: 'PAID',
      courier: 'Pedro Díaz',
      amount: 80,
      fee: 8,
      toDeliver: 32800,
      delivered: 80,
      voided: {'at': '2026-10-12T13:03:00Z', 'by': 'u1', 'byName': 'Admin', 'reason': reasonWithSeparator},
    ),
    _row(
      'OT-H2N6LC',
      createdAt: '2026-10-20T15:00:00Z',
      status: 'PAID',
      currency: 'USD',
      rate: 1,
      amount: 50,
      fee: 5,
      toDeliver: 50,
      delivered: 50,
    ),
  ],
};

/// `GET /reports/monthly` of the same month.
final monthlyJson = <String, dynamic>{
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'generatedAt': '2026-11-01T13:05:00Z',
  'businessCurrency': 'USD',
  'remittances': {'total': 4, 'delivery': 3, 'pickup': 1, 'completed': 2, 'open': 2, 'withIncident': 1},
  'collected': 402.00,
  'fees': 35.00,
  'deliveredCurrency': 386.95,
  'difference': 15.05,
  'roundingMargin': 0.05,
  'pickups': {'remittances': 1, 'collected': 200.00, 'fees': 20.00},
  'onTheHouse': {'remittances': 1, 'amount': 237.00, 'waivedFees': 23.70},
  'delivered': [
    {'currency': 'CUP', 'amount': 138150.00},
    {'currency': 'USD', 'amount': 50.00},
  ],
  'byCurrency': [
    {
      'currency': 'CUP',
      'remittances': 2,
      'sent': 337.00,
      'fees': 10.00,
      'collected': 347.00,
      'delivered': 138150.00,
      'deliveredCurrency': 336.95,
    },
    {
      'currency': 'USD',
      'remittances': 1,
      'sent': 50.00,
      'fees': 5.00,
      'collected': 55.00,
      'delivered': 50.00,
      'deliveredCurrency': 50.00,
    },
  ],
  'byType': [
    {'type': 'DELIVERY', 'remittances': 3, 'collected': 402.00, 'fees': 15.00},
    {'type': 'PICKUP', 'remittances': 1, 'collected': 200.00, 'fees': 20.00},
  ],
};

Map<String, dynamic> _row(
  String code, {
  String type = 'DELIVERY',
  required String createdAt,
  required String status,
  String? completedAt,
  bool fromBusiness = false,
  (String, String) municipality = ('2302', 'Plaza de la Revolución'),
  String? courier,
  String currency = 'CUP',
  double rate = 410,
  required double amount,
  required double fee,
  required double toDeliver,
  double? delivered,
  double? collected,
  double? onTheHouse,
  bool incident = false,
  Map<String, dynamic>? voided,
}) => {
  'id': 'id-$code',
  'code': code,
  'type': type,
  'status': status,
  'statusName': status,
  'createdAt': createdAt,
  'expectedDate': createdAt.substring(0, 10),
  'completedAt': completedAt,
  'completedFromBusiness': fromBusiness,
  'municipalityCode': municipality.$1,
  'municipalityName': municipality.$2,
  'courierName': courier,
  'sourceCurrency': 'USD',
  'targetCurrency': currency,
  'amount': amount,
  'fee': fee,
  'total': amount + fee,
  'rate': rate,
  'amountToDeliver': toDeliver,
  'collected': collected ?? amount + fee,
  'deliveredCurrency': delivered,
  'onTheHouse': onTheHouse != null,
  'waivedFee': onTheHouse,
  'withIncident': incident,
  'voided': voided,
};

Map<String, dynamic> _figures(int remittances, {int pickups = 0, double collected = 0, double fees = 0}) => {
  'remittances': remittances,
  'deliveries': remittances - pickups,
  'pickups': pickups,
  'deliveryAmount': collected - fees,
  'averageAmount': remittances - pickups == 0 ? 0 : (collected - fees) / (remittances - pickups),
  'collected': collected,
  'fees': fees,
  'deliveredCurrency': collected - fees,
  'pickupCollected': pickups * 100.0,
  'onTheHouse': {'remittances': 0, 'amount': 0, 'waivedFees': 0},
};

/// `GET /reports/statistics` of a period: [weekly] remittances per week
/// (deliveries of 110 charged, 10 of fee each), from Monday 2026-09-28.
Map<String, dynamic> statisticsJson({
  List<int> weekly = const [6, 4, 8, 5],
  int onTheHouse = 1,
  List<(String, String, int)>? municipalities,
}) {
  final total = weekly.fold(0, (sum, count) => sum + count);
  final weeks = [
    for (final (index, count) in weekly.indexed)
      {
        'week': '2026-W${40 + index}',
        'from': DateTime.utc(2026, 9, 28 + 7 * index).toIso8601String().substring(0, 10),
        'to': DateTime.utc(2026, 9, 28 + 7 * index + 6).toIso8601String().substring(0, 10),
        'partial': false,
        ..._figures(count, collected: count * 110.0, fees: count * 10.0),
      },
  ];
  final totals = _figures(total, collected: total * 110.0, fees: total * 10.0);
  if (onTheHouse > 0) {
    totals['onTheHouse'] = {'remittances': onTheHouse, 'amount': onTheHouse * 100.0, 'waivedFees': onTheHouse * 10.0};
  }
  final days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  return {
    'from': '2026-09-28',
    'to': weeks.isEmpty ? '2026-09-28' : weeks.last['to'],
    'generatedAt': '2026-10-23T20:00:00Z',
    'businessCurrency': 'USD',
    'totals': totals,
    'byWeek': weeks,
    'byMonth': [
      {'month': '2026-09', 'from': '2026-09-28', 'to': '2026-09-30', 'partial': true, ..._figures(0)},
      {'month': '2026-10', 'from': '2026-10-01', 'to': '2026-10-25', 'partial': true, ...totals},
    ],
    'byDayOfWeek': [
      for (final (index, day) in days.indexed)
        {'dayOfWeek': day, ..._figures(index == 0 ? total : 0, collected: index == 0 ? total * 110.0 : 0)},
    ],
    'byMunicipality': [
      for (final (code, name, count) in municipalities ?? [('2302', 'Plaza de la Revolución', total)])
        {'municipalityCode': code, 'municipalityName': name, ..._figures(count)},
    ],
  };
}
