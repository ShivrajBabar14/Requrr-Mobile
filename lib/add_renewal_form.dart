import 'dart:convert';
import 'package:flutter/material.dart';
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

  const AddRenewalForm({
    Key? key,
    required this.clients,
    required this.services,
    required this.token,
    required this.onSuccess,
    required this.onClose,
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

  @override
  void initState() {
    super.initState();
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

      // Simulated delay or replace with actual API call
      final response = await http.post(
        Uri.parse('https://yourdomain.com/api/income_records'),
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
        } else {
          dueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Renewal'),
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
                            (c) => DropdownMenuItem(
                              value: c['id'].toString(),
                              child: Text(c['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedClientId = val;
                        });
                      },
                      validator: (val) =>
                          val == null ? 'Please select a client' : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Service'),
                      value: selectedServiceId,
                      items: widget.services
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'].toString(),
                              child: Text(s['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedServiceId = val;
                        });
                      },
                      validator: (val) =>
                          val == null ? 'Please select a service' : null,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => amount = val,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter amount'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Overdue'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            status = val;
                          });
                        }
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              hintText: paymentDate != null
                                  ? DateFormat(
                                      'dd-MM-yyyy',
                                    ).format(paymentDate!)
                                  : '',
                            ),
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              hintText: dueDate != null
                                  ? DateFormat('dd-MM-yyyy').format(dueDate!)
                                  : '',
                            ),
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                      onChanged: (val) => notes = val,
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
        TextButton(onPressed: widget.onClose, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: loading ? null : _submitForm,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
