import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'sidebar.dart'; // ✅ Import your Sidebar widget

class SubscriptionPage extends StatefulWidget {
  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> plans = [];

  @override
  void initState() {
    super.initState();
    fetchPlans();
  }

  Future<void> fetchPlans() async {
    try {
      final response = await http.get(Uri.parse("https://www.requrr.com/api/plans"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          plans = data;
        });
      } else {
        print("Error fetching plans: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Widget buildPlanCard(Map<String, dynamic> plan) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.black, size: 32),
          const SizedBox(height: 8),
          Center(
            child: Text(
              plan['name'] ?? 'Plan Name',
              style: GoogleFonts.questrial(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (plan['description'] ?? '')
                  .toString()
                  .split('\n')
                  .map((line) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• ", style: TextStyle(fontSize: 14, color: Colors.black)),
                          Expanded(
                            child: Text(
                              line.trim(),
                              style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (plan['price'] == "0.00" || plan['price'] == 0) ? "Free" : "₹${plan['price']}",
            style: GoogleFonts.questrial(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Pay via UPI mandate, cancel anytime",
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // TODO: handle plan selection
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Select ${plan['name']} plan", style: GoogleFonts.questrial()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.questrialTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Sidebar(), // ✅ Add your Sidebar here
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer(); // ✅ This opens the drawer
            },
          ),
          title: Text(
            "Choose a Plan",
            style: GoogleFonts.questrial(color: Colors.black, fontSize: 15),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.grey.withOpacity(0.5),
        ),
        backgroundColor: Colors.white,
        body: plans.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  return buildPlanCard(plans[index]);
                },
              ),
      ),
    );
  }
}
