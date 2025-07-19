// Paste this entire file as `subscription.dart`

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> plans = [];
  int? selectedPlanIndex;

  Map<int, String> couponInputs = {};
  Map<int, String> couponValidation = {};
  Map<int, double> discountedPrices = {};
  Map<String, dynamic>? currentPlan;

  Map<int, bool> couponLoading = {};

  String userCountry = 'IN';
  String currencySymbol = '₹';
  bool isIndia = true;

  late Razorpay _razorpay;

  int _currentVerifyingPlanId = 0;
  String _currentCoupon = '';
  double _currentFinalPrice = 0;

  String _authToken = '';

  @override
  void initState() {
    super.initState();
    _initData();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Sidebar(),
      appBar: AppBar(
        title: const Text(
          "Choose a Plan",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: plans.length,
              itemBuilder: (context, index) =>
                  buildPlanCard(plans[index], index),
            ),
    );
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please login again.'),
          ),
        );
      }
      return;
    }
    _authToken = token;
    await fetchData();
  }

  Future<void> fetchData() async {
    try {
      final plansRes = await http.get(
        Uri.parse("https://www.requrr.com/api/plans"),
      );
      if (plansRes.statusCode == 200) {
        setState(() => plans = json.decode(plansRes.body));
      }

      final subRes = await http.get(
        Uri.parse("https://www.requrr.com/api/subscription/status"),
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
        Uri.parse("https://www.requrr.com/api/me"),
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

  Future<void> validateCoupon(int planId) async {
    final code = couponInputs[planId] ?? '';
    setState(() {
      couponLoading[planId] = true;
      couponValidation[planId] = '';
    });
    try {
      final res = await http.post(
        Uri.parse("https://www.requrr.com/api/payment/create-order"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'planId': planId,
          'couponCode': code,
          'userCurrency': isIndia ? 'INR' : 'USD',
        }),
      );

      final data = json.decode(res.body);
      if (data['error'] == null) {
        setState(() {
          couponValidation[planId] = 'success';
          discountedPrices[planId] = isIndia
              ? (data['finalPrice'] is int
                  ? (data['finalPrice'] as int).toDouble()
                  : (data['finalPrice'] as double))
              : (data['localPrice'] is int
                  ? (data['localPrice'] as int).toDouble()
                  : (data['localPrice'] as double));
        });
      } else {
        setState(() {
          couponValidation[planId] = 'error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Invalid coupon code')),
          );
        });
      }
    } catch (e) {
      setState(() {
        couponValidation[planId] = 'error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validating coupon: $e')),
        );
      });
    } finally {
      setState(() {
        couponLoading[planId] = false;
      });
    }
  }

  Future<void> handlePayment(
    int planId,
    double price,
    String planName, [
    String couponCode = '',
  ]) async {
    if (_authToken.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    final res = await http.post(
      Uri.parse("https://www.requrr.com/api/payment/create-order"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'planId': planId,
        'couponCode': couponCode,
        'userCurrency': isIndia ? 'INR' : 'USD',
      }),
    );

    final order = json.decode(res.body);
    if (order['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(order['error'])));
      return;
    }

    _currentVerifyingPlanId = planId;
    _currentCoupon = couponCode;
    _currentFinalPrice =
        double.tryParse(order['localPrice'].toString()) ?? price;

    var razorpayAmount = (order['amount'] as num?)?.toInt() ?? 0;
    if (order['localCurrency'] == 'INR') razorpayAmount *= 100;

    var options = {
      'key': 'rzp_test_K2K20arHghyhnD',
      'amount': razorpayAmount,
      'currency': order['localCurrency'],
      'name': 'Requrr',
      'description':
          '$planName Plan - $currencySymbol${_currentFinalPrice} ${order['localCurrency']}/year',
      'order_id': order['id'],
      'theme': {'color': '#3399cc'},
    };

    _razorpay.open(options);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final verifyRes = await http.post(
      Uri.parse("https://www.requrr.com/api/payment/verify"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      },
      body: jsonEncode({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'plan_id': _currentVerifyingPlanId,
        'coupon_code': _currentCoupon,
        'final_price': _currentFinalPrice,
        'currency': isIndia ? 'INR' : 'USD',
      }),
    );

    final result = json.decode(verifyRes.body);
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment succeeded but DB update failed: ${result['error']}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Payment and subscription successful',
          ),
        ),
      );
    }
    fetchData();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Payment failed')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  Widget buildPlanCard(Map<String, dynamic> plan, int index) {
    final planId = plan['id'] ?? index;
    final basePrice = isIndia
        ? (double.tryParse(plan['price_inr']?.toString() ?? '') ?? 0)
        : (double.tryParse(plan['price_usd']?.toString() ?? '') ?? 0);
    final finalPrice = discountedPrices[planId] ?? basePrice;
    final isCurrentPlan =
        currentPlan != null && currentPlan!['plan_name'] == plan['name'];
    final currentPrice = currentPlan?['price'] ?? 0;
    final isUpgrade = currentPlan == null || basePrice > currentPrice;
    final disableButton = isCurrentPlan || !isUpgrade;
    final validated = couponValidation[planId];

    bool isFreePlan = plan['name']?.toString().toLowerCase() == 'free';

    bool showCouponInput = couponInputs.containsKey(planId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1), // black border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // center content horizontally
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // center row content horizontally
            children: [
              Expanded(
                child: Text(
                  plan['name'] ?? '',
                  textAlign: TextAlign.center, // center text
                  style: GoogleFonts.questrial(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isCurrentPlan)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Activated Plan',
                    style: GoogleFonts.questrial(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan['description'] ?? '',
            textAlign: TextAlign.center, // center description text
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            "$currencySymbol${finalPrice.toStringAsFixed(2)} / year",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (!isCurrentPlan && !isFreePlan) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (showCouponInput) {
                      couponInputs.remove(planId);
                      couponValidation[planId] = '';
                      discountedPrices.remove(planId);
                    } else {
                      couponInputs[planId] = '';
                      couponValidation[planId] = '';
                    }
                  });
                },
                child: Text(
                  showCouponInput ? 'Hide Coupon' : 'Apply Coupon?',
                  style: const TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            if (showCouponInput) ...[
              TextField(
                decoration: InputDecoration(
                  labelText: "Coupon Code",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => couponInputs[planId] = val),
                onSubmitted: (val) {
                  validateCoupon(planId);
                },
              ),
              const SizedBox(height: 8),
              if (couponValidation[planId] == 'success')
                const Text(
                  "Coupon applied successfully 🎉",
                  style: TextStyle(color: Colors.green, fontSize: 14),
                )
              else if (couponValidation[planId] == 'error')
                const Text(
                  "Invalid coupon code",
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
            ],
          ],
          if (!isCurrentPlan)
          ElevatedButton(
            onPressed: () => handlePayment(
              planId,
              discountedPrices[planId] ?? finalPrice,
              plan['name'] ?? '',
              couponInputs[planId] ?? '',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.black,
            ),
            child: Text(
              "Subscribe $currencySymbol${((discountedPrices[planId] ?? finalPrice) / 12).toStringAsFixed(2)} /month",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

}
