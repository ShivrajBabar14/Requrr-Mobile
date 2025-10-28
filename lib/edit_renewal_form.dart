import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'subscription_limit_dialog.dart';
import 'subscription.dart';

class EditRenewalDialog extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> services;
  final void Function() onSuccess;
  final String token;
  final bool hasSubscription;
  final int currentRenewalCount;
  final Map<String, dynamic> initialData;

  const EditRenewalDialog({
    Key? key,
    required this.clients,
    required this.services,
    required this.onSuccess,
    required this.token,
    required this.hasSubscription,
    required this.currentRenewalCount,
    required this.initialData,
  }) : super(key: key);

  @override
  _EditRenewalDialogState createState() => _EditRenewalDialogState();
}

class _EditRenewalDialogState extends State<EditRenewalDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedClientId;
  String? selectedServiceId;
  String amount = '';
  DateTime? paymentDate;
  DateTime? dueDate;
  String status = 'pending';
  bool isRecurring = false;
  String notes = '';
  String? limitError;
  bool loading = false;

  late TextEditingController amountController;
  late TextEditingController notesController;
  late TextEditingController paymentDateController;
  late TextEditingController dueDateController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController();
    notesController = TextEditingController();
    paymentDateController = TextEditingController();
    dueDateController = TextEditingController();

    selectedClientId = widget.initialData['client_id']?.toString();
    selectedServiceId = widget.initialData['service_id']?.toString();
    amount = widget.initialData['amount']?.toString() ?? '';
    status = widget.initialData['status'] ?? 'pending';
    notes = widget.initialData['notes'] ?? '';

    if (widget.initialData['payment_date'] != null) {
      paymentDate = DateTime.parse(widget.initialData['payment_date']);
    }
    if (widget.initialData['due_date'] != null) {
      dueDate = DateTime.parse(widget.initialData['due_date']);
    }

    amountController.text = amount;
    notesController.text = notes;
    paymentDateController.text =
        paymentDate != null ? DateFormat('dd-MM-yyyy').format(paymentDate!) : '';
    dueDateController.text =
        dueDate != null ? DateFormat('dd-MM-yyyy').format(dueDate!) : '';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!widget.hasSubscription && widget.currentRenewalCount >= 5) {
      showDialog(
        context: context,
        builder: (context) => SubscriptionLimitDialog(
          currentRenewals: widget.currentRenewalCount,
          limit: 5,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final payload = {
      "client_id": int.tryParse(selectedClientId ?? ''),
      "service_id": int.tryParse(selectedServiceId ?? ''),
      "amount": double.tryParse(amountController.text) ?? 0,
      "payment_date": paymentDate != null
          ? DateFormat('yyyy-MM-dd').format(paymentDate!)
          : '',
      "due_date": dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : '',
      "status": status,
      "is_recurring": isRecurring,
      "recurrence_id": null,
      "notes": notesController.text,
    };

    final response = await http.put(
      Uri.parse('https://www.requrr.com/api/income_records/${widget.initialData['id']}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(payload),
    );

    setState(() => loading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      widget.onSuccess();
      Navigator.pop(context);
    } else {
      final error = jsonDecode(response.body);
      final errorMessage = error['message'] ?? 'Try again';

      if (response.statusCode == 403 ||
          errorMessage.toLowerCase().contains('limit') ||
          errorMessage.toLowerCase().contains('subscription')) {
        showDialog(
          context: context,
          builder: (context) => SubscriptionLimitDialog(
            currentRenewals: widget.currentRenewalCount,
            limit: 5,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $errorMessage')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPaymentDate) async {
    final initialDate = isPaymentDate
        ? (paymentDate ?? DateTime.now())
        : (dueDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isPaymentDate) {
          paymentDate = picked;
          paymentDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        } else {
          dueDate = picked;
          dueDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    paymentDateController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Renewal'),
      content: loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Client'),
                      value: selectedClientId,
                      items: widget.clients
                          .map(
                            (client) => DropdownMenuItem(
                              value: client['id'].toString(),
                              child: Text(client['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedClientId = val),
                      validator: (val) =>
                          val == null ? 'Please select a client' : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Service'),
                      value: selectedServiceId,
                      items: widget.services
                          .map(
                            (service) => DropdownMenuItem(
                              value: service['id'].toString(),
                              child: Text(service['service'] ?? service['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedServiceId = val),
                      validator: (val) =>
                          val == null ? 'Please select a service' : null,
                    ),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter amount' : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (val) => setState(() => status = val ?? 'pending'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: paymentDateController,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'Start Date'),
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: dueDateController,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'End Date'),
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isRecurring,
                          onChanged: (val) =>
                              setState(() => isRecurring = val ?? false),
                        ),
                        const Text('Is Recurring'),
                      ],
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                    if (limitError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          limitError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: loading ? null : _submitForm,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
