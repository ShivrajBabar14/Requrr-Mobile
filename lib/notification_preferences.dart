import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({Key? key}) : super(key: key);

  @override
  _NotificationPreferencesPageState createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool remind30DaysBefore = false;
  bool remind15DaysBefore = false;
  bool remind7DaysBefore = false;
  bool remindOverdue = false;
  bool emailNotifications = false;
  bool dashboardNotifications = false;
  bool paymentReceivedNotifications = false;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchPreferences() async {
    setState(() {
      loading = true;
    });

    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unauthorized: No token found.')),
      );
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://www.requrr.com/api/notification-preferences'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          remind30DaysBefore = (data['remind_30_days_before'] is int)
              ? (data['remind_30_days_before'] == 1)
              : (data['remind_30_days_before'] ?? false);
          remind15DaysBefore = (data['remind_15_days_before'] is int)
              ? (data['remind_15_days_before'] == 1)
              : (data['remind_15_days_before'] ?? false);
          remind7DaysBefore = (data['remind_7_days_before'] is int)
              ? (data['remind_7_days_before'] == 1)
              : (data['remind_7_days_before'] ?? false);
          remindOverdue = (data['remind_overdue'] is int)
              ? (data['remind_overdue'] == 1)
              : (data['remind_overdue'] ?? false);
          emailNotifications = (data['email_notifications'] is int)
              ? (data['email_notifications'] == 1)
              : (data['email_notifications'] ?? false);
          dashboardNotifications = (data['dashboard_notifications'] is int)
              ? (data['dashboard_notifications'] == 1)
              : (data['dashboard_notifications'] ?? false);
          paymentReceivedNotifications =
              (data['payment_received_notifications'] is int)
              ? (data['payment_received_notifications'] == 1)
              : (data['payment_received_notifications'] ?? false);
          loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch preferences: ${response.statusCode}',
            ),
          ),
        );
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch preferences: $e')),
      );
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unauthorized: No token found.')),
      );
      return;
    }

    final prefs = {
      'remind_30_days_before': remind30DaysBefore,
      'remind_15_days_before': remind15DaysBefore,
      'remind_7_days_before': remind7DaysBefore,
      'remind_overdue': remindOverdue,
      'email_notifications': emailNotifications,
      'dashboard_notifications': dashboardNotifications,
      'payment_received_notifications': paymentReceivedNotifications,
    };

    try {
      final response = await http.put(
        Uri.parse('https://www.requrr.com/api/notification-preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(prefs),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences saved ✅')));
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save preferences: ${data['error'] ?? 'Unknown error'}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save preferences: $e')));
    }
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Transform.scale(
        scale: 0.8, // Reduce switch size
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.black, // Thumb when active
          activeTrackColor: Colors.grey.shade300, // Track when active
          inactiveThumbColor: Colors.black, // Thumb when inactive
          inactiveTrackColor: Colors.white, // Track when inactive
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      
    }

    return Scaffold(
     
      body: DefaultTextStyle(
        style: GoogleFonts.questrial(fontSize: 16, color: Colors.black),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              const SizedBox(height: 24),

              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Renewal Reminders',
                        style: GoogleFonts.questrial(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        '30 days before expiry',
                        'Send a reminder 30 days before renewal is due',
                        remind30DaysBefore,
                        (val) => setState(() => remind30DaysBefore = val),
                      ),
                      _buildSwitchTile(
                        '15 days before expiry',
                        'Send a reminder 15 days before renewal is due',
                        remind15DaysBefore,
                        (val) => setState(() => remind15DaysBefore = val),
                      ),
                      _buildSwitchTile(
                        '7 days before expiry',
                        'Send a reminder 7 days before renewal is due',
                        remind7DaysBefore,
                        (val) => setState(() => remind7DaysBefore = val),
                      ),
                      _buildSwitchTile(
                        'Overdue renewals',
                        'Send reminders for overdue renewals',
                        remindOverdue,
                        (val) => setState(() => remindOverdue = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Methods',
                        style: GoogleFonts.questrial(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        'Email Notifications',
                        'Receive notifications via email',
                        emailNotifications,
                        (val) => setState(() => emailNotifications = val),
                      ),
                      _buildSwitchTile(
                        'Dashboard Notifications',
                        'Show notifications in the dashboard',
                        dashboardNotifications,
                        (val) => setState(() => dashboardNotifications = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Other Notifications',
                        style: GoogleFonts.questrial(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        'Payment Received',
                        'Notify when a payment is recorded',
                        paymentReceivedNotifications,
                        (val) =>
                            setState(() => paymentReceivedNotifications = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: ElevatedButton(
                  onPressed: _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Save Preferences',
                    style: GoogleFonts.questrial(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
