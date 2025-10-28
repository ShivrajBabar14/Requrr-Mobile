import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'dashboard.dart';

class RecurringExpensePage extends StatefulWidget {
  const RecurringExpensePage({super.key});

  @override
  State<RecurringExpensePage> createState() => _RecurringExpensePageState();
}

class _RecurringExpensePageState extends State<RecurringExpensePage> {
  List expenses = [];
  String? token;
  bool loading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    fetchTokenAndData();
  }

  Future<void> fetchTokenAndData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('accessToken') ?? prefs.getString('token');
    if (token != null) {
      fetchExpenses();
    }
  }

  Future<void> fetchExpenses() async {
    setState(() {
      loading = true;
    });

    try {
      if (token == null || token!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication token is missing. Please login again.',
            ),
          ),
        );
        setState(() {
          loading = false;
        });
        return;
      }

      final url = Uri.parse(
        'https://requrr-web-v2.vercel.app/api/requrring_expenses',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        setState(() {
          expenses = decoded;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch expenses: ${response.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching expenses: $e')));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _showAddExpenseDialog() async {
    final _formKey = GlobalKey<FormState>();

    String title = '';
    String amount = '';
    String frequency = 'monthly';
    String status = 'pending';
    DateTime? paymentDate;
    DateTime? dueDate;
    String notes = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Recurring Expense',
                        style: GoogleFonts.questrial(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter title';
                          }
                          return null;
                        },
                        onChanged: (value) => title = value,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) => amount = value,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yearly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              frequency = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              status = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Start Date *',
                                labelStyle: GoogleFonts.questrial(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: const Icon(Icons.calendar_today, size: 20),
                              ),
                              controller: TextEditingController(
                                text: paymentDate != null ? DateFormat('yyyy-MM-dd').format(paymentDate!) : '',
                              ),
                              validator: (value) {
                                if (paymentDate == null) {
                                  return 'Please select a start date';
                                }
                                return null;
                              },
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    paymentDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Due Date',
                                labelStyle: GoogleFonts.questrial(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: const Icon(Icons.calendar_today, size: 20),
                              ),
                              controller: TextEditingController(
                                text: dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : '',
                              ),
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    dueDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (value) => notes = value,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.questrial(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _addExpense(
                                  title,
                                  amount,
                                  paymentDate,
                                  dueDate,
                                  frequency,
                                  status,
                                  notes,
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text('Add', style: GoogleFonts.questrial()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addExpense(
    String title,
    String amount,
    DateTime? paymentDate,
    DateTime? dueDate,
    String frequency,
    String status,
    String notes,
  ) async {
    setState(() {
      loading = true;
    });

    try {
      final url = Uri.parse(
        'https://requrr-web-v2.vercel.app/api/requrring_expenses',
      );
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'payment_date': paymentDate?.toIso8601String(),
          'due_date': dueDate?.toIso8601String(),
          'frequency': frequency,
          'status': status,
          'notes': notes,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        fetchExpenses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add expense: ${response.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding expense: $e')));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _showEditExpenseDialog(Map expense) async {
    final _formKey = GlobalKey<FormState>();

    String title = expense['title'] ?? '';
    String amount = expense['amount']?.toString() ?? '';
    String frequency = expense['frequency'] ?? 'monthly';
    String status = expense['status'] ?? 'pending';
    DateTime? paymentDate = expense['payment_date'] != null
        ? DateTime.tryParse(expense['payment_date'])
        : null;
    DateTime? dueDate = expense['due_date'] != null
        ? DateTime.tryParse(expense['due_date'])
        : null;
    String notes = expense['notes'] ?? '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Recurring Expense',
                        style: GoogleFonts.questrial(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        initialValue: title,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter title';
                          }
                          return null;
                        },
                        onChanged: (value) => title = value,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: amount,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) => amount = value,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yearly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              frequency = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              status = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: InputDatePickerFormField(
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              fieldLabelText: 'Start Date',
                              initialDate: paymentDate ?? DateTime.now(),
                              onDateSubmitted: (date) {
                                setState(() {
                                  paymentDate = date;
                                });
                              },
                              onDateSaved: (date) {
                                paymentDate = date;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                labelStyle: GoogleFonts.questrial(
                                  color: Colors.grey[600],
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              controller: TextEditingController(
                                text: paymentDate != null
                                    ? DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(paymentDate!)
                                    : '',
                              ),
                              validator: (value) {
                                if (paymentDate == null) {
                                  return 'Please select a start date';
                                }
                                return null;
                              },
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    paymentDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        initialValue: notes,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (value) => notes = value,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.questrial(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _editExpense(
                                  expense['id'],
                                  title,
                                  amount,
                                  paymentDate,
                                  dueDate,
                                  frequency,
                                  status,
                                  notes,
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            child: Text(
                              'Update',
                              style: GoogleFonts.questrial(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editExpense(
    int id,
    String title,
    String amount,
    DateTime? paymentDate,
    DateTime? dueDate,
    String frequency,
    String status,
    String notes,
  ) async {
    setState(() {
      loading = true;
    });

    try {
      final url = Uri.parse(
        'https://requrr-web-v2.vercel.app/api/requrring_expenses/$id',
      );
      final response = await http.put(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'payment_date': paymentDate?.toIso8601String(),
          'due_date': dueDate?.toIso8601String(),
          'frequency': frequency,
          'status': status,
          'notes': notes,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        fetchExpenses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update expense: ${response.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating expense: $e')));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _deleteExpense(int id) async {
    bool confirmed = false;
    confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Confirm Delete'),
            content: const Text(
              'Are you sure you want to delete this expense?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.black),),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      loading = true;
    });

    try {
      final url = Uri.parse(
        'https://requrr-web-v2.vercel.app/api/requrring_expenses/$id',
      );
      final response = await http.delete(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        fetchExpenses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete expense: ${response.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting expense: $e')));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Widget _expenseCard(Map expense) {
    final bool isActive = expense['status'] == 'paid';
    final Color statusColor = isActive ? Colors.blue : Colors.grey;
    final paymentDate = expense['payment_date'] != null
        ? DateTime.tryParse(expense['payment_date'])
        : null;
    final dueDate = expense['due_date'] != null
        ? DateTime.tryParse(expense['due_date'])
        : null;
    final amount = double.tryParse(expense['amount'] ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense['title'] ?? '-',
                    style: GoogleFonts.questrial(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (expense['status'] ?? '').toString().capitalize(),
                    style: GoogleFonts.questrial(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showEditExpenseDialog(expense),
                  child: const Icon(Icons.edit, size: 18, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _deleteExpense(expense['id']),
                  child: const Icon(
                    Icons.delete,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ₹${NumberFormat('#,##0.00').format(amount)}',
              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
            ),
            Text(
              'Start Date: ${paymentDate != null ? DateFormat('dd-MM-yyyy').format(paymentDate) : '-'}',
              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
            ),
            Text(
              'Due Date: ${dueDate != null ? DateFormat('dd-MM-yyyy').format(dueDate) : '-'}',
              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
            ),
            Text(
              'Frequency: ${(expense['frequency'] ?? '-').toString().capitalize()}',
              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
            ),
            Text(
              'Notes: ${expense['notes'] ?? '-'}',
              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => Dashboard(token: token),
              ),
            );
          },
        ),
        title: Text(
          'Recurring Expenses',
          style: GoogleFonts.questrial(color: Colors.black, fontSize: 15),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.5),
      ),
body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: expenses.isEmpty
                    ? [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/expenses.png',
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 20),
                               
                              ],
                            ),
                          ),
                        ),
                      ]
                    : expenses.map((e) => _expenseCard(e)).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
