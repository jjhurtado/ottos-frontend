import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../widgets/resolve_review_dialog.dart';

/// Couriers' currency exchanges marked for an unusual rate (or a late sync),
/// to check and resolve with a note. Nothing when there are none.
class ExchangesToReview extends StatefulWidget {
  const ExchangesToReview({super.key, this.onResolved});

  /// The cash changed view: e.g. reload the page around it.
  final VoidCallback? onResolved;

  @override
  State<ExchangesToReview> createState() => _ExchangesToReviewState();
}

class _ExchangesToReviewState extends State<ExchangesToReview> {
  late Future<PageResult<CurrencyExchange>> _pending = _load();

  Future<PageResult<CurrencyExchange>> _load() => context.read<CashRepository>().exchanges(review: true, size: 50);

  void _reload() {
    setState(() {
      _pending = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canResolve = context.canDo(Permissions.cashReview);
    return FutureBuilder<PageResult<CurrencyExchange>>(
      future: _pending,
      builder: (context, snapshot) {
        final exchanges = snapshot.data?.items ?? const <CurrencyExchange>[];
        if (exchanges.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: OttosColors.warning),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: OttosColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      '${OpsTexts.exchangesToReview} (${snapshot.data!.totalItems})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final exchange in exchanges)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${exchange.courierName ?? ''} · ${OpsTexts.exchangeLine(Formatters.money(exchange.fromAmount, exchange.fromCurrency), Formatters.money(exchange.toAmount, exchange.toCurrency))}',
                    ),
                    subtitle: Text(
                      [
                        '${Formatters.dateTime(exchange.occurredAt)} · ${CoreTexts.reviewReason(exchange.review!.reason)}',
                        OpsTexts.exchangeRates(
                          Formatters.money(exchange.rate, null),
                          exchange.configuredRate == null ? null : Formatters.money(exchange.configuredRate, null),
                          exchange.deviationPercent == null ? null : Formatters.money(exchange.deviationPercent, null),
                        ),
                        if (exchange.note != null && exchange.note!.isNotEmpty) exchange.note!,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: canResolve
                        ? FilledButton.tonal(
                            onPressed: () async {
                              final cash = context.read<CashRepository>();
                              final messenger = ScaffoldMessenger.of(context);
                              final note = await askResolveNote(context);
                              if (note == null) return;
                              try {
                                await cash.resolveExchangeReview(exchange.id, note: note);
                                messenger.showSnackBar(const SnackBar(content: Text(OpsTexts.exchangeReviewResolved)));
                                _reload();
                                widget.onResolved?.call();
                              } on ApiException catch (error) {
                                messenger.showSnackBar(SnackBar(content: Text(error.message)));
                              }
                            },
                            child: const Text(OpsTexts.resolve),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
