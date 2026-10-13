import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import 'cash_widgets.dart';

/// One courier's cash as sales see it from «Caja»: the same balances and
/// movements the courier sees in «Mi caja» (`cash:read`, online only), with
/// funding and returns for who can move cash (`cash:write`).
class CourierCashPage extends StatefulWidget {
  const CourierCashPage({super.key, required this.courierId});

  final String courierId;

  @override
  State<CourierCashPage> createState() => _CourierCashPageState();
}

class _CourierCashPageState extends State<CourierCashPage> {
  late Future<CourierStatement> _statement = _load();

  Future<CourierStatement> _load() => context.read<CashRepository>().courierStatement(widget.courierId);

  Future<void> _reload() {
    final next = _load();
    setState(() {
      _statement = next;
    });
    return next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourierStatement>(
      future: _statement,
      builder: (context, snapshot) {
        final statement = snapshot.data;
        final error = snapshot.error;
        return Scaffold(
          appBar: AppBar(title: Text(statement?.cash.name ?? CourierTexts.courierCash)),
          body: switch ((statement, error)) {
            (_, final Object error) when snapshot.connectionState == ConnectionState.done => ErrorView(
              message: error is ApiException ? error.message : CoreTexts.unexpectedError,
              onRetry: _reload,
            ),
            (null, _) => const LoadingView(),
            (final CourierStatement statement, _) => RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  BalancesCard(cash: statement.cash, owesText: CourierTexts.courierOwesBusiness),
                  if (context.canDo(Permissions.cashWrite)) ...[
                    const SizedBox(height: 8),
                    _CashButtons(courier: statement.cash, onMoved: _reload),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(CourierTexts.movements, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (statement.movements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyView(message: CourierTexts.courierNoMovements),
                    ),
                  for (final movement in statement.movements) MovementTile(movement: movement),
                  if (statement.movements.length >= 100)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(CourierTexts.latestMovements, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          },
        );
      },
    );
  }
}

/// «Entregar fondos» and «Registrar devolución», as on the courier's card in «Caja».
class _CashButtons extends StatelessWidget {
  const _CashButtons({required this.courier, required this.onMoved});

  final CourierCash courier;
  final Future<void> Function() onMoved;

  @override
  Widget build(BuildContext context) {
    final cash = context.read<CashRepository>();
    final currencies = {'USD', 'CUP', for (final balance in courier.balances) balance.currency}.toList();

    Future<void> operate(String title, String confirm, Future<CashMovement> Function(CashInput) submit) async {
      final messenger = ScaffoldMessenger.of(context);
      final movement = await showCashOperationDialog(
        context,
        title: title,
        confirmLabel: confirm,
        currencies: currencies,
        submit: submit,
      );
      if (movement == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text(CourierTexts.movementRegistered(Formatters.money(movement.amount, movement.currency)))),
      );
      await onMoved();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => operate(
              CourierTexts.fundTitle(courier.name),
              CourierTexts.fund,
              (input) => cash.fundCourier(courier.courierId, input),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text(CourierTexts.fund),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => operate(
              CourierTexts.returnTitle(courier.name),
              CourierTexts.registerReturn,
              (input) => cash.courierReturn(courier.courierId, input),
            ),
            icon: const Icon(Icons.arrow_back),
            label: const Text(CourierTexts.registerReturn),
          ),
        ),
      ],
    );
  }
}
