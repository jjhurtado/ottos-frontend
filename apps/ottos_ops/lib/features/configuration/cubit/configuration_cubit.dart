import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum ConfigurationStatus { loading, success, failure }

final class ConfigurationState extends Equatable {
  const ConfigurationState({
    this.status = ConfigurationStatus.loading,
    this.settings = const Settings(),
    this.corridors = const [],
    this.error,
  });

  final ConfigurationStatus status;
  final Settings settings;
  final List<Corridor> corridors;
  final String? error;

  @override
  List<Object?> get props => [status, settings, corridors, error];
}

/// Business settings and the corridors with the rate and fee rule in force.
class ConfigurationCubit extends Cubit<ConfigurationState> {
  ConfigurationCubit({required this._rates}) : super(const ConfigurationState());

  final RateRepository _rates;

  /// Loads everything; after a change it refreshes in place, keeping the page.
  Future<void> load() async {
    if (state.status != ConfigurationStatus.success) emit(const ConfigurationState());
    try {
      final results = await Future.wait<Object>([_rates.settings(), _rates.corridors()], eagerError: true);
      // Active first, then by code.
      final corridors = [...results[1] as List<Corridor>]
        ..sort((a, b) => a.active == b.active ? a.code.compareTo(b.code) : (a.active ? -1 : 1));
      emit(
        ConfigurationState(status: ConfigurationStatus.success, settings: results[0] as Settings, corridors: corridors),
      );
    } on ApiException catch (error) {
      emit(ConfigurationState(status: ConfigurationStatus.failure, error: error.message));
    }
  }
}
