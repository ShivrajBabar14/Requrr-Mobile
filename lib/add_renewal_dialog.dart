import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddRenewalDialog extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> services;
  final void Function() onSuccess;
  final String token;

  const AddRenewalDialog({
    Key? key,
    required this.clients,
    required this.services,
    required this.onSuccess,
    required this.token,
  }) : super(key: key);

  @override
  _AddRenewalDialogState createState() => _AddRenewalDialogState();
}

class _AddRenewalDialogState extends State<AddRenewalDialog> {
  final _formKey = GlobalKey<FormState>();

  int? selectedClientId;
  int? selectedServiceId;
  TextEditingController amountController = TextEditingController();
  TextEditingController paymentDateController = TextEditingController();
  TextEditingController dueDateController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  bool isRecurring = false;
  String? recurrenceId;

  bool isSubmitting = false;
  String status = 'pending';

  void _onServiceChanged(int? serviceId) {
    if (serviceId != null) {
      final service = widget.services.firstWhere((s) => s['id'] == serviceId);
      setState(() {
        selectedServiceId = serviceId;
        amountController.text = service['base_price']?.toString() ?? '';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    final payload = {
      "client_id": selectedClientId,
      "service_id": selectedServiceId,
      "amount": double.tryParse(amountController.text) ?? 0,
      "payment_date": paymentDateController.text,
      "due_date": dueDateController.text,
      "status": "pending",
      "is_recurring": isRecurring,
      "recurrence_id": recurrenceId,
      "notes": notesController.text,
    };

    final response = await http.post(
      Uri.parse('https://www.requrr.com/api/income_records'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode(payload),
    );

    setState(() {
      isSubmitting = false;
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      widget.onSuccess();
      Navigator.pop(context);
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${error['message'] ?? 'Try again'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Renewal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Client Dropdown
              DropdownButtonFormField<int>(
                value: selectedClientId,
                decoration: const InputDecoration(labelText: 'Client'),
              items: widget.clients.map((client) {
                return DropdownMenuItem<int>(
                  value: client['id'],
                  child: Text(client['name'] ?? 'Unknown'),
                );
              }).toList(),
                onChanged: (val) => setState(() => selectedClientId = val),
                validator: (val) => val == null ? 'Please select a client' : null,
              ),

              const SizedBox(height: 12),

              // Service Dropdown
              DropdownButtonFormField<int>(
                value: selectedServiceId,
                decoration: const InputDecoration(labelText: 'Service'),
              items: widget.services.map((service) {
                return DropdownMenuItem<int>(
                  value: service['id'],
                  child: Text(service['service'] ?? service['name'] ?? 'Unknown'),
                );
              }).toList(),
                onChanged: _onServiceChanged,
                validator: (val) => val == null ? 'Please select a service' : null,
              ),

              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Enter amount' : null,
              ),

              const SizedBox(height: 12),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  setState(() {
                    status = val ?? 'pending';
                  });
                },
                validator: (val) => val == null ? 'Please select a status' : null,
              ),

              const SizedBox(height: 12),

              // Start Date (Payment Date)
              TextFormField(
                controller: paymentDateController,
                decoration: const InputDecoration(labelText: 'Start Date'),
                validator: (val) => val == null || val.isEmpty ? 'Enter start date' : null,
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    paymentDateController.text = pickedDate.toIso8601String().split('T')[0];
                    setState(() {});
                  }
                },
              ),

              const SizedBox(height: 12),

              // End Date (Due Date)
              TextFormField(
                controller: dueDateController,
                decoration: const InputDecoration(labelText: 'End Date'),
                validator: (val) => val == null || val.isEmpty ? 'Enter end date' : null,
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    dueDateController.text = pickedDate.toIso8601String().split('T')[0];
                    setState(() {});
                  }
                },
              ),

              const SizedBox(height: 12),


              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submitForm,
          child: isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
