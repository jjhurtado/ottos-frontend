import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

/// Keeps the panel's business time zone up to date (REQ-006, AC-2.3): the
/// shell asks for it when the panel opens, when the tab comes back to the
/// front and when the user opens another section. The zone itself lives in
/// [BusinessTime]; the state is the last one received.
class BusinessTimeCubit extends Cubit<BusinessTimeZone> {
  BusinessTimeCubit({required this._rates}) : super(BusinessTime.zone);

  final RateRepository _rates;

  Future<void> refresh() async {
    try {
      final zone = await _rates.businessTime();
      if (zone != null && !isClosed) emit(zone);
    } on ApiException {
      // An older server, or no network: the zone in use stays.
    }
  }
}
