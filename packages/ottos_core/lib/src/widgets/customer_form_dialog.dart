import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../customers/customer_repository.dart';
import '../l10n/core_texts.dart';
import '../models/customer.dart';
import 'form_pair.dart';

/// Creates a customer, or edits [customer]; returns the saved one, or null if cancelled.
Future<Customer?> showCustomerFormDialog(BuildContext context, {Customer? customer}) {
  final customers = context.read<CustomerRepository>();
  return showDialog<Customer>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CustomerFormDialog(customers: customers, customer: customer),
  );
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({required this.customers, this.customer});

  final CustomerRepository customers;
  final Customer? customer;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.customer?.fullName);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _documentType = TextEditingController(text: widget.customer?.documentType);
  late final _documentNumber = TextEditingController(text: widget.customer?.documentNumber);
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _notes = TextEditingController(text: widget.customer?.notes);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_fullName, _phone, _email, _documentType, _documentNumber, _address, _notes]) {
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
    final input = CustomerInput(
      fullName: _fullName.text,
      phone: _phone.text,
      email: _email.text,
      documentType: _documentType.text,
      documentNumber: _documentNumber.text,
      address: _address.text,
      notes: _notes.text,
    );
    try {
      final existing = widget.customer;
      final saved = existing == null
          ? await widget.customers.create(input)
          : await widget.customers.update(existing.id, input);
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
      title: Text(widget.customer == null ? CoreTexts.newCustomer : CoreTexts.editCustomer),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_fullName, CoreTexts.fullName, required: true, autofocus: true),
                _field(_phone, CoreTexts.phone, required: true, keyboard: TextInputType.phone, validator: phoneError),
                _field(_email, CoreTexts.email, keyboard: TextInputType.emailAddress, validator: _emailError),
                FormPair(
                  first: _field(_documentNumber, CoreTexts.documentNumber),
                  second: _field(_documentType, CoreTexts.documentType),
                  secondWidth: 160,
                ),
                _field(_address, CoreTexts.address),
                _field(_notes, CoreTexts.notes, maxLines: 2),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
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
              : const Text(CoreTexts.save),
        ),
      ],
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
          if (text.isEmpty) return required ? CoreTexts.requiredField : null;
          return validator?.call(text);
        },
      ),
    );
  }

  static String? _emailError(String email) => email.contains('@') ? null : CoreTexts.emailInvalid;
}

/// Phones may carry a leading `+`, spaces and dashes; the backend normalizes them.
String? phoneError(String phone) {
  final digits = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^\+?\d{6,15}$').hasMatch(digits) ? null : CoreTexts.phoneInvalid;
}
