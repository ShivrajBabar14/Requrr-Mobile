import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription.dart'; // 👈 Make sure this matches your route

class AddRenewalForm extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> services;
  final String token;
  final VoidCallback onSuccess;
  final VoidCallback onClose;
  final Map<String, dynamic>? initialData; // For editing

  const AddRenewalForm({
    Key? key,
    required this.clients,
    required this.services,
    required this.token,
    required this.onSuccess,
    required this.onClose,
    this.initialData,
  }) : super(key: key);

  @override
  _AddRenewalFormState createState() => _AddRenewalFormState();
}

class _AddRenewalFormState extends State<AddRenewalForm> {
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

    if (widget.initialData != null) {
      selectedClientId = widget.initialData!['client_id']?.toString();
      selectedServiceId = widget.initialData!['service_id']?.toString();
      amount = widget.initialData!['amount']?.toString() ?? '';
      status = widget.initialData!['status'] ?? 'pending';
      notes = widget.initialData!['notes'] ?? '';
      if (widget.initialData!['payment_date'] != null) {
        paymentDate = DateTime.parse(widget.initialData!['payment_date']);
      }
      if (widget.initialData!['due_date'] != null) {
        dueDate = DateTime.parse(widget.initialData!['due_date']);
      }
    }

    amountController.text = amount;
    notesController.text = notes;
    paymentDateController.text = paymentDate != null ? DateFormat('dd-MM-yyyy').format(paymentDate!) : '';
    dueDateController.text = dueDate != null ? DateFormat('dd-MM-yyyy').format(dueDate!) : '';
  }

  Future<Map<String, dynamic>?> getSubscriptionStatus(String token) async {
    final res = await http.get(
      Uri.parse('https://yourdomain.com/api/subscription/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      return null;
    }
  }

  Future<int> getRenewalCount(String token) async {
    final res = await http.get(
      Uri.parse('https://yourdomain.com/api/income_records?count_only=true'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['count'] ?? 0;
    }

    return 0;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedClientId == null || selectedServiceId == null) {
      setState(() {
        limitError = 'Please select client and service';
      });
      return;
    }

    setState(() {
      loading = true;
      limitError = null;
    });

    try {
      // 👇 Subscription check
      final subStatus = await getSubscriptionStatus(widget.token);
      final isFree = subStatus == null || subStatus['subscribed'] == false;
      if (isFree) {
        final renewalCount = await getRenewalCount(widget.token);
        if (renewalCount >= 5) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Upgrade Required'),
                content: const Text(
                  'You have reached your free plan limit. Please subscribe to continue.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SubscriptionPage()),
                      );
                    },
                    child: const Text('Subscribe'),
                  ),
                ],
              ),
            );
          }
          setState(() => loading = false);
          return;
        }
      }

      final data = {
        'client_id': selectedClientId,
        'service_id': selectedServiceId,
        'amount': amount,
        'payment_date': paymentDate != null
            ? DateFormat('yyyy-MM-dd').format(paymentDate!)
            : '',
        'due_date': dueDate != null
            ? DateFormat('yyyy-MM-dd').format(dueDate!)
            : '',
        'status': status,
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_id': '',
        'notes': notes,
      };

      final isEditing = widget.initialData != null;
      final url = isEditing
          ? 'https://yourdomain.com/api/income_records/${widget.initialData!['id']}'
          : 'https://yourdomain.com/api/income_records';
      final method = isEditing ? http.put : http.post;

      final response = await method(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSuccess();
      } else if (response.statusCode == 403) {
        final resBody = json.decode(response.body);
        setState(() {
          limitError = resBody['error'] ?? 'You have reached your plan limit.';
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Upgrade Required'),
            content: Text(
              '${resBody['error'] ?? 'Free plan limit reached.'}\nPlease subscribe to a paid plan to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) =>  SubscriptionPage()),
                  );
                },
                child: const Text('Subscribe'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          limitError = 'Something went wrong.';
        });
      }
    } catch (e) {
      setState(() {
        limitError = 'Something went wrong.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
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
    final isEditing = widget.initialData != null;
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
                isEditing ? 'Edit Renewal' : 'Add Renewal',
                style: GoogleFonts.questrial(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: selectedClientId,
                decoration: _inputDecoration('Client'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                items: widget.clients.map((client) {
                  return DropdownMenuItem<String>(
                    value: client['id'].toString(),
                    child: Text(client['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedClientId = val),
                validator: (val) =>
                    val == null ? 'Please select a client' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedServiceId,
                decoration: _inputDecoration('Service'),
                style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                items: widget.services.map((service) {
                  return DropdownMenuItem<String>(
                    value: service['id'].toString(),
                    child: Text(service['service'] ?? service['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedServiceId = val),
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
                    initialDate: paymentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      paymentDate = picked;
                      paymentDateController.text =
                          picked.toIso8601String().split('T')[0];
                    });
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
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      dueDate = picked;
                      dueDateController.text =
                          picked.toIso8601String().split('T')[0];
                    });
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
                    onPressed: loading ? null : () => Navigator.pop(context),
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
                    onPressed: loading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update' : 'Add',
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
