import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import 'movement_tile.dart';

/// A courier's cash: balances, latest movements, and funding or returns.
class CourierCashPage extends StatefulWidget {
  const CourierCashPage({super.key, required this.courierId});

  final String courierId;

  @override
  State<CourierCashPage> createState() => _CourierCashPageState();
}

class _CourierCashPageState extends State<CourierCashPage> {
  late Future<CourierStatement> _statement;

  @override
  void initState() {
    super.initState();
    _statement = _load();
  }

  Future<CourierStatement> _load() => context.read<CashRepository>().courierStatement(widget.courierId);

  void _reload() {
    // A block, not an arrow: setState must not return the future.
    setState(() {
      _statement = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourierStatement>(
      future: _statement,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is ApiException ? error.message : CoreTexts.unexpectedError,
            onRetry: _reload,
          );
        }
        final statement = snapshot.data;
        if (statement == null) return const LoadingView();
        return _CourierCashView(statement: statement, onChanged: _reload);
      },
    );
  }
}

class _CourierCashView extends StatelessWidget {
  const _CourierCashView({required this.statement, required this.onChanged});

  final CourierStatement statement;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cash = statement.cash;
    final canWrite = context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.cashWrite));
    final repository = context.read<CashRepository>();
    final colors = Theme.of(context).colorScheme;
    final currencies = {'USD', 'CUP', for (final balance in cash.balances) balance.currency}.toList();

    Future<void> operate(String title, String confirm, Future<CashMovement> Function(CashInput) submit) async {
      final movement = await showCashOperationDialog(
        context,
        title: title,
        confirmLabel: confirm,
        currencies: currencies,
        submit: submit,
      );
      if (movement == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OpsTexts.movementRegistered(Formatters.money(movement.amount, movement.currency)))),
      );
      onChanged();
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Destinations.cash.path),
            icon: const Icon(Icons.arrow_back),
            label: const Text(OpsTexts.cash),
          ),
        ),
        const SizedBox(height: 8),
        Text(cash.name, style: Theme.of(context).textTheme.headlineMedium),
        if (cash.negative) ...[
          const SizedBox(height: 8),
          Text(OpsTexts.courierOwes, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 16),
        if (canWrite)
          Wrap(
            spacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => operate(
                  OpsTexts.fundCourierTitle(cash.name),
                  OpsTexts.fund,
                  (input) => repository.fundCourier(cash.courierId, input),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(OpsTexts.fund),
              ),
              OutlinedButton.icon(
                onPressed: () => operate(
                  OpsTexts.courierReturnTitle(cash.name),
                  OpsTexts.registerReturn,
                  (input) => repository.courierReturn(cash.courierId, input),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text(OpsTexts.registerReturn),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final input = await showExchangeDialog(context, title: OpsTexts.exchangeForTitle(cash.name));
                  if (input == null) return;
                  try {
                    final exchange = await repository.exchangeFor(cash.courierId, input);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(exchange.pendingReview ? OpsTexts.exchangeFlagged : OpsTexts.exchangeRegistered),
                      ),
                    );
                    onChanged();
                  } on ApiException catch (error) {
                    messenger.showSnackBar(SnackBar(content: Text(error.message)));
                  }
                },
                icon: const Icon(Icons.currency_exchange),
                label: const Text(OpsTexts.registerExchange),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(OpsTexts.balance, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (cash.balances.isEmpty) const Text(OpsTexts.noBalances),
                for (final balance in cash.balances)
                  InfoRow(label: balance.currency, value: Formatters.money(balance.amount, null)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(OpsTexts.latestMovements, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (statement.movements.isEmpty) const Text(OpsTexts.noMovements),
                for (final movement in statement.movements) MovementTile(movement: movement),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
