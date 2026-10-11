import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../audit/audit_repository.dart';
import '../auth/auth_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/token_storage.dart';
import '../cash/cash_repository.dart';
import '../config/app_config.dart';
import '../customers/customer_repository.dart';
import '../customers/zone_repository.dart';
import '../rates/rate_repository.dart';
import '../remittances/remittance_repository.dart';
import '../sync/sync_repository.dart';
import '../users/role_repository.dart';
import '../users/user_repository.dart';

/// Creates the shared services and provides them to [child]: [ApiClient],
/// [AuthRepository], [RemittanceRepository], [CashRepository], [CustomerRepository],
/// [RateRepository], [ZoneRepository], [UserRepository], [RoleRepository], [SyncRepository], the app's [AccessPolicy] and
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
  late final CustomerRepository _customerRepository;
  late final RateRepository _rateRepository;
  late final ZoneRepository _zoneRepository;
  late final UserRepository _userRepository;
  late final RoleRepository _roleRepository;
  late final SyncRepository _syncRepository;
  late final AuditRepository _auditRepository;

  @override
  void initState() {
    super.initState();
    final tokenStorage = SecureTokenStorage();
    _api = ApiClient(config: widget.config, tokenStorage: tokenStorage);
    _authRepository = AuthRepository(
      api: _api,
      tokenStorage: tokenStorage,
      client: widget.config.client,
      userCache: widget.config.client == AppClient.mobile ? SecureUserCache() : null,
    );
    _remittanceRepository = RemittanceRepository(api: _api);
    _cashRepository = CashRepository(api: _api);
    _customerRepository = CustomerRepository(api: _api);
    _rateRepository = RateRepository(api: _api);
    _zoneRepository = ZoneRepository(api: _api);
    _userRepository = UserRepository(api: _api);
    _roleRepository = RoleRepository(api: _api);
    _syncRepository = SyncRepository(api: _api);
    _auditRepository = AuditRepository(api: _api);
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
        RepositoryProvider.value(value: _customerRepository),
        RepositoryProvider.value(value: _rateRepository),
        RepositoryProvider.value(value: _zoneRepository),
        RepositoryProvider.value(value: _userRepository),
        RepositoryProvider.value(value: _roleRepository),
        RepositoryProvider.value(value: _syncRepository),
        RepositoryProvider.value(value: _auditRepository),
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
