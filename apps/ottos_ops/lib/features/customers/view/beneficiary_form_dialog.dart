import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import 'customer_form_dialog.dart';

/// Creates a beneficiary for [customerId], or edits [beneficiary]; returns the
/// saved one, or null if cancelled.
Future<Beneficiary?> showBeneficiaryFormDialog(
  BuildContext context, {
  required String customerId,
  Beneficiary? beneficiary,
}) {
  final customers = context.read<CustomerRepository>();
  final zones = context.read<ZoneRepository>();
  return showDialog<Beneficiary>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BeneficiaryFormDialog(
      customers: customers,
      zones: Future.wait([zones.provinces(), zones.municipalities()]),
      customerId: customerId,
      beneficiary: beneficiary,
    ),
  );
}

class _BeneficiaryFormDialog extends StatefulWidget {
  const _BeneficiaryFormDialog({
    required this.customers,
    required this.zones,
    required this.customerId,
    this.beneficiary,
  });

  final CustomerRepository customers;
  final Future<List<List<Object>>> zones;
  final String customerId;
  final Beneficiary? beneficiary;

  @override
  State<_BeneficiaryFormDialog> createState() => _BeneficiaryFormDialogState();
}

class _BeneficiaryFormDialogState extends State<_BeneficiaryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _b = widget.beneficiary;
  late final _fullName = TextEditingController(text: _b?.fullName);
  late final _phone = TextEditingController(text: _b?.phone);
  late final _alternatePhone = TextEditingController(text: _b?.alternatePhone);
  late final _street = TextEditingController(text: _b?.street);
  late final _houseNumber = TextEditingController(text: _b?.houseNumber);
  late final _betweenStreets = TextEditingController(text: _b?.betweenStreets);
  late final _neighborhood = TextEditingController(text: _b?.neighborhood);
  late final _reference = TextEditingController(text: _b?.reference);
  late final _documentNumber = TextEditingController(text: _b?.documentNumber);
  late final _notes = TextEditingController(text: _b?.notes);
  String? _provinceCode;
  late String? _municipalityCode = _b?.municipalityCode;
  bool _saving = false;
  String? _error;

  List<TextEditingController> get _controllers => [
    _fullName,
    _phone,
    _alternatePhone,
    _street,
    _houseNumber,
    _betweenStreets,
    _neighborhood,
    _reference,
    _documentNumber,
    _notes,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = BeneficiaryInput(
      fullName: _fullName.text,
      phone: _phone.text,
      alternatePhone: _alternatePhone.text,
      street: _street.text,
      houseNumber: _houseNumber.text,
      betweenStreets: _betweenStreets.text,
      neighborhood: _neighborhood.text,
      municipalityCode: _municipalityCode!,
      reference: _reference.text,
      documentNumber: _documentNumber.text,
      notes: _notes.text,
    );
    try {
      final existing = widget.beneficiary;
      final saved = existing == null
          ? await widget.customers.addBeneficiary(widget.customerId, input)
          : await widget.customers.updateBeneficiary(existing.id, input);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.beneficiary == null ? OpsTexts.newBeneficiary : OpsTexts.editBeneficiary),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<List<List<Object>>>(
          future: widget.zones,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              return ErrorView(message: error is ApiException ? error.message : CoreTexts.unexpectedError);
            }
            final zones = snapshot.data;
            if (zones == null) return const SizedBox(height: 200, child: LoadingView());
            return _form(zones[0].cast<Province>(), zones[1].cast<Municipality>());
          },
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(OpsTexts.save),
        ),
      ],
    );
  }

  Widget _form(List<Province> provinces, List<Municipality> municipalities) {
    // When editing, the province comes from the saved municipality.
    _provinceCode ??= municipalities.where((m) => m.code == _municipalityCode).firstOrNull?.provinceCode;
    final inProvince = municipalities.where((m) => m.provinceCode == _provinceCode).toList();
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_fullName, OpsTexts.fullName, required: true, autofocus: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    _phone,
                    OpsTexts.phone,
                    required: true,
                    keyboard: TextInputType.phone,
                    validator: phoneError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _alternatePhone,
                    OpsTexts.alternatePhone,
                    keyboard: TextInputType.phone,
                    validator: phoneError,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_street, OpsTexts.street, required: true)),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: _field(_houseNumber, OpsTexts.houseNumber)),
              ],
            ),
            _field(_betweenStreets, OpsTexts.betweenStreets),
            _field(_neighborhood, OpsTexts.neighborhood),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _provinceCode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '${OpsTexts.province} *'),
                      items: [
                        for (final province in provinces)
                          DropdownMenuItem(value: province.code, child: Text(province.name)),
                      ],
                      onChanged: _saving
                          ? null
                          : (code) => setState(() {
                              _provinceCode = code;
                              _municipalityCode = null;
                            }),
                      validator: (code) => code == null ? OpsTexts.requiredField : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_provinceCode),
                      initialValue: inProvince.any((m) => m.code == _municipalityCode) ? _municipalityCode : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '${OpsTexts.municipality} *'),
                      items: [
                        for (final municipality in inProvince)
                          DropdownMenuItem(value: municipality.code, child: Text(municipality.name)),
                      ],
                      onChanged: _saving ? null : (code) => setState(() => _municipalityCode = code),
                      validator: (code) => code == null ? OpsTexts.requiredField : null,
                    ),
                  ),
                ),
              ],
            ),
            _field(_reference, OpsTexts.reference),
            _field(_documentNumber, OpsTexts.documentNumber),
            _field(_notes, OpsTexts.notes, maxLines: 2),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool autofocus = false,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        autofocus: autofocus,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return required ? OpsTexts.requiredField : null;
          return validator?.call(text);
        },
      ),
    );
  }
}
