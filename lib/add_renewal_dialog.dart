import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'subscription_limit_dialog.dart';

class AddRenewalDialog extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> services;
  final void Function() onSuccess;
  final String token;
  final bool hasSubscription;
  final int currentRenewalCount;

  const AddRenewalDialog({
    Key? key,
    required this.clients,
    required this.services,
    required this.onSuccess,
    required this.token,
    required this.hasSubscription,
    required this.currentRenewalCount,
  }) : super(key: key);

  @override
  _AddRenewalDialogState createState() => _AddRenewalDialogState();
}

class _AddRenewalDialogState extends State<AddRenewalDialog> {
  final _formKey = GlobalKey<FormState>();

  int? selectedClientId;
  int? selectedServiceId;
  String status = 'pending';
  bool isRecurring = false;
  String? recurrenceId;

  final amountController = TextEditingController();
  final paymentDateController = TextEditingController();
  final dueDateController = TextEditingController();
  final notesController = TextEditingController();

  bool isSubmitting = false;

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

    // Check subscription and renewal count limit
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

    setState(() => isSubmitting = true);

    final payload = {
      "client_id": selectedClientId,
      "service_id": selectedServiceId,
      "amount": double.tryParse(amountController.text) ?? 0,
      "payment_date": paymentDateController.text,
      "due_date": dueDateController.text,
      "status": status,
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

    setState(() => isSubmitting = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      widget.onSuccess();
      Navigator.pop(context);
    } else {
      final error = jsonDecode(response.body);
      final errorMessage = error['message'] ?? 'Try again';

      print('AddRenewalDialog submission error: $errorMessage');

      // Show subscription dialog if 403 status or limit exceeded message
      if (response.statusCode == 403 || errorMessage.toLowerCase().contains('limit') || errorMessage.toLowerCase().contains('subscription')) {
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.questrial(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Renewal',
                style: GoogleFonts.questrial(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                value: selectedClientId,
                decoration: _inputDecoration('Client'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                items: widget.clients.map((client) {
                  return DropdownMenuItem<int>(
                    value: client['id'],
                    child: Text(client['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedClientId = val),
                validator: (val) =>
                    val == null ? 'Please select a client' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: selectedServiceId,
                decoration: _inputDecoration('Service'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                items: widget.services.map((service) {
                  return DropdownMenuItem<int>(
                    value: service['id'],
                    child: Text(service['service'] ?? service['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: _onServiceChanged,
                validator: (val) =>
                    val == null ? 'Please select a service' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: amountController,
                decoration: _inputDecoration('Amount (₹)'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter amount' : null,
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: status,
                decoration: _inputDecoration('Status'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (val) => setState(() => status = val ?? 'pending'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: paymentDateController,
                readOnly: true,
                decoration: _inputDecoration('Start Date'),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    paymentDateController.text =
                        picked.toIso8601String().split('T')[0];
                  }
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter start date' : null,
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: dueDateController,
                readOnly: true,
                decoration: _inputDecoration('End Date'),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    dueDateController.text =
                        picked.toIso8601String().split('T')[0];
                  }
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter end date' : null,
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Checkbox(
                    value: isRecurring,
                    onChanged: (val) =>
                        setState(() => isRecurring = val ?? false),
                  ),
                  Text(
                    'Is Recurring',
                    style: GoogleFonts.questrial(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: notesController,
                decoration: _inputDecoration('Notes'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.questrial(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: GoogleFonts.questrial(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
