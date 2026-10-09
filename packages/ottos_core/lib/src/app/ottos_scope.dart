import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../auth/auth_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/token_storage.dart';
import '../cash/cash_repository.dart';
import '../config/app_config.dart';
import '../remittances/remittance_repository.dart';

/// Creates the shared services and provides them to [child]: [ApiClient],
/// [AuthRepository], [RemittanceRepository], [CashRepository], the app's [AccessPolicy] and
/// the [AuthBloc] (already started).
class OttosScope extends StatefulWidget {
  const OttosScope({super.key, required this.config, required this.accessPolicy, required this.child});

  final AppConfig config;
  final AccessPolicy accessPolicy;
  final Widget child;

  @override
  State<OttosScope> createState() => _OttosScopeState();
}

class _OttosScopeState extends State<OttosScope> {
  late final ApiClient _api;
  late final AuthRepository _authRepository;
  late final RemittanceRepository _remittanceRepository;
  late final CashRepository _cashRepository;

  @override
  void initState() {
    super.initState();
    final tokenStorage = SecureTokenStorage();
    _api = ApiClient(config: widget.config, tokenStorage: tokenStorage);
    _authRepository = AuthRepository(api: _api, tokenStorage: tokenStorage);
    _remittanceRepository = RemittanceRepository(api: _api);
    _cashRepository = CashRepository(api: _api);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _api),
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _remittanceRepository),
        RepositoryProvider.value(value: _cashRepository),
        RepositoryProvider<AccessPolicy>.value(value: widget.accessPolicy),
      ],
      child: BlocProvider(
        create: (_) =>
            AuthBloc(authRepository: _authRepository, accessPolicy: widget.accessPolicy)..add(const AuthStarted()),
        child: widget.child,
      ),
    );
  }
}
