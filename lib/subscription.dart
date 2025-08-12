// Paste this file as `subscription.dart`

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar.dart';
import 'payment_success.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> plans = [];
  Map<String, dynamic>? currentPlan;

  String userCountry = 'IN';
  String currencySymbol = '₹';
  bool isIndia = true;
  String _authToken = '';

  late Razorpay _razorpay;

  int _currentVerifyingPlanId = 0;
  double _currentFinalPrice = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated. Please login again.')),
        );
      }
      return;
    }
    _authToken = token;
    await fetchData();
  }

  Future<void> fetchData() async {
    try {
      final plansRes = await http.get(Uri.parse("https://requrr-web-v2.vercel.app/api/plans"));
      if (plansRes.statusCode == 200) {
        setState(() => plans = json.decode(plansRes.body));
      }

      final subRes = await http.get(
        Uri.parse("https://requrr-web-v2.vercel.app/api/subscription/status"),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (subRes.statusCode == 200) {
        final subData = json.decode(subRes.body);
        if (subData['subscribed'] == true) {
          setState(() {
            currentPlan = {
              'plan_name': subData['plan_name'],
              'price': double.tryParse(subData['price_inr'].toString()) ?? 0.0,
              'max_renewals': subData['max_renewals'],
            };
          });
        }
      }

      final userRes = await http.get(
        Uri.parse("https://requrr-web-v2.vercel.app/api/me"),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      if (userRes.statusCode == 200) {
        final user = json.decode(userRes.body);
        final country = (user['country_code'] ?? 'IN').toString().toUpperCase();
        setState(() {
          userCountry = country;
          isIndia = country == 'IN';
          currencySymbol = isIndia ? '₹' : '\$';
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> handlePayment(int planId, double price, String planName) async {
    final res = await http.post(
      Uri.parse("https://requrr-web-v2.vercel.app/api/subscription/create"),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'planId': planId}),
    );

    final data = json.decode(res.body);
    if (data['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'])));
      return;
    }

    _currentVerifyingPlanId = planId;
    _currentFinalPrice = price;

    _razorpay.open({
      'key': 'rzp_test_K2K20arHghyhnD', // Replace with LIVE key in prod
      'subscription_id': data['subscription_id'],
      'name': 'Requrr',
      'description': 'Subscribe to $planName',
      'theme': {'color': '#3399cc'},
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final verifyRes = await http.post(
      Uri.parse("https://requrr-web-v2.vercel.app/api/subscription/update"),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'planId': _currentVerifyingPlanId,
        'razorpay_subscription_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'final_price': _currentFinalPrice,
      }),
    );

    final result = json.decode(verifyRes.body);
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DB update failed: ${result['error']}')),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      );
    }
    fetchData();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wallet selected: ${response.walletName}')),
    );
  }

  Widget buildPlanCard(Map<String, dynamic> plan, int index) {
    final planId = plan['id'] ?? index;
    final price = isIndia
        ? (double.tryParse(plan['price_inr']?.toString() ?? '') ?? 0)
        : (double.tryParse(plan['price_usd']?.toString() ?? '') ?? 0);

    final isCurrentPlan =
        currentPlan != null && currentPlan!['plan_name'] == plan['name'];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          Text(plan['name'] ?? '', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(plan['description'] ?? ''),
          const SizedBox(height: 12),
          Text(
            "$currencySymbol${price.toStringAsFixed(2)} / year",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!isCurrentPlan)
            ElevatedButton(
              onPressed: () => handlePayment(planId, price, plan['name'] ?? ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text(
                "Subscribe @ ${currencySymbol}${(price / 12).toStringAsFixed(2)}/month",
              ),
            )
          else
            const Text("This is your current plan", style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Sidebar(),
      appBar: AppBar(
        title: const Text("Choose a Plan", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: plans.length,
              itemBuilder: (context, index) => buildPlanCard(plans[index], index),
            ),
    );
  }
}
