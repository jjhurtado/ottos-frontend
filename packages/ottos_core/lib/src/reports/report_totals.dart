import 'package:equatable/equatable.dart';

import '../models/report_detail.dart';

/// The sums of some remittances of the month's detail, voided ones left out,
/// with the monthly report's rules: they match `GET /reports/monthly` when
/// every row of the month goes in.
class ReportTotals extends Equatable {
  const ReportTotals({
    this.remittances = 0,
    this.deliveries = 0,
    this.pickups = 0,
    this.voided = 0,
    this.sent = 0,
    this.collected = 0,
    this.deliveryFees = 0,
    this.pickupFees = 0,
    this.deliveredCurrency = 0,
    this.pickupCollected = 0,
    this.onTheHouse = 0,
    this.onTheHouseAmount = 0,
    this.waivedFees = 0,
  });

  factory ReportTotals.of(Iterable<ReportRemittance> rows) {
    var remittances = 0, deliveries = 0, pickups = 0, voided = 0, onTheHouse = 0;
    var sent = 0.0, collected = 0.0, deliveryFees = 0.0, pickupFees = 0.0;
    var deliveredCurrency = 0.0, pickupCollected = 0.0, onTheHouseAmount = 0.0, waivedFees = 0.0;
    for (final row in rows) {
      if (row.isVoided) {
        voided++;
        continue;
      }
      remittances++;
      if (row.isPickup) {
        pickups++;
        pickupCollected += row.collected;
        pickupFees += row.fee;
      } else {
        deliveries++;
        sent += row.amount;
        collected += row.collected;
        deliveryFees += row.fee;
        deliveredCurrency += row.deliveredCurrency ?? 0;
        if (row.onTheHouse) {
          onTheHouse++;
          onTheHouseAmount += row.amount;
          waivedFees += row.waivedFee ?? 0;
        }
      }
    }
    // Cents, as the backend rounds each sum.
    double round(double value) => (value * 100).roundToDouble() / 100;
    return ReportTotals(
      remittances: remittances,
      deliveries: deliveries,
      pickups: pickups,
      voided: voided,
      sent: round(sent),
      collected: round(collected),
      deliveryFees: round(deliveryFees),
      pickupFees: round(pickupFees),
      deliveredCurrency: round(deliveredCurrency),
      pickupCollected: round(pickupCollected),
      onTheHouse: onTheHouse,
      onTheHouseAmount: round(onTheHouseAmount),
      waivedFees: round(waivedFees),
    );
  }

  final int remittances;
  final int deliveries;
  final int pickups;

  /// Voided rows among the ones summed: listed apart, never added.
  final int voided;

  /// What the deliveries sent.
  final double sent;

  /// Charged for the deliveries: amount + fee.
  final double collected;
  final double deliveryFees;
  final double pickupFees;
  final double deliveredCurrency;

  /// What the couriers collected in the pickups.
  final double pickupCollected;
  final int onTheHouse;
  final double onTheHouseAmount;
  final double waivedFees;

  /// The earnings: fees of deliveries and pickups.
  double get fees => ((deliveryFees + pickupFees) * 100).roundToDouble() / 100;

  @override
  List<Object?> get props => [
    remittances,
    deliveries,
    pickups,
    voided,
    sent,
    collected,
    deliveryFees,
    pickupFees,
    deliveredCurrency,
    pickupCollected,
    onTheHouse,
    onTheHouseAmount,
    waivedFees,
  ];
}

/// What the month's list shows by status.
enum ReportStatusFilter { all, paid, assigned, completed, incident }

/// The filters of the month's list, applied in the app (the endpoint returns
/// the whole month).
class ReportFilter extends Equatable {
  const ReportFilter({
    this.code = '',
    this.type,
    this.status = ReportStatusFilter.all,
    this.courier,
    this.onlyOnTheHouse = false,
    this.showVoided = true,
    this.newestFirst = true,
  });

  /// Part of the code, any case.
  final String code;

  /// Null: deliveries and pickups.
  final String? type;
  final ReportStatusFilter status;

  /// Null: every courier; [withoutCourier]: the ones without one.
  final String? courier;
  final bool onlyOnTheHouse;
  final bool showVoided;
  final bool newestFirst;

  static const withoutCourier = '';

  bool get isFiltered =>
      code.isNotEmpty || type != null || status != ReportStatusFilter.all || courier != null || onlyOnTheHouse;

  ReportFilter copyWith({
    String? code,
    String? Function()? type,
    ReportStatusFilter? status,
    String? Function()? courier,
    bool? onlyOnTheHouse,
    bool? showVoided,
    bool? newestFirst,
  }) => ReportFilter(
    code: code ?? this.code,
    type: type == null ? this.type : type(),
    status: status ?? this.status,
    courier: courier == null ? this.courier : courier(),
    onlyOnTheHouse: onlyOnTheHouse ?? this.onlyOnTheHouse,
    showVoided: showVoided ?? this.showVoided,
    newestFirst: newestFirst ?? this.newestFirst,
  );

  bool matches(ReportRemittance row) {
    if (row.isVoided && !showVoided) return false;
    final query = code.trim().toUpperCase();
    if (query.isNotEmpty && !row.code.toUpperCase().contains(query)) return false;
    if (type != null && row.type.code != type) return false;
    if (onlyOnTheHouse && !row.onTheHouse) return false;
    if (courier != null && (row.courierName ?? withoutCourier) != courier) return false;
    // A voided one has no status that counts: it shows only without a status filter.
    if (status != ReportStatusFilter.all && row.isVoided) return false;
    return switch (status) {
      ReportStatusFilter.all => true,
      ReportStatusFilter.paid => row.status == 'PAID',
      ReportStatusFilter.assigned => row.status == 'ASSIGNED',
      ReportStatusFilter.completed => row.isCompleted,
      ReportStatusFilter.incident => row.withIncident,
    };
  }

  /// The rows that pass, in the chosen order (the backend sends them oldest first).
  List<ReportRemittance> apply(List<ReportRemittance> rows) {
    final shown = rows.where(matches).toList();
    return newestFirst ? shown.reversed.toList() : shown;
  }

  @override
  List<Object?> get props => [code, type, status, courier, onlyOnTheHouse, showVoided, newestFirst];
}
