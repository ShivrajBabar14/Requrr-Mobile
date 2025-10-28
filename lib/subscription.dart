// Updated subscription.dart to match web implementation
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar.dart';
import 'payment_success.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard.dart';

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
  String? token;

  late Razorpay _razorpay;

  int _currentVerifyingPlanId = 0;
  double _currentFinalPrice = 0;

  // Coupon functionality
  final Map<String, String> _couponInputs = {};
  final Map<String, bool> _showCouponPopup = {};
  final Map<String, String> _couponValidation = {};
  final Map<String, double> _discountedPrices = {};

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initData();
    fetchToken();
  }

  Future<void> fetchToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('accessToken') ?? prefs.getString('token');
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
          final subPrice = isIndia 
              ? double.tryParse(subData['price_inr'].toString()) ?? 0.0
              : double.tryParse(subData['price_usd'].toString()) ?? 0.0;
          setState(() {
            currentPlan = {
              'plan_name': subData['plan_name'],
              'price': subPrice,
              'start_date': subData['start_date'],
              'end_date': subData['end_date'],
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

  Future<void> _handleValidateCoupon(int planId) async {
    final code = _couponInputs[planId.toString()] ?? '';
    if (code.isEmpty) return;

    try {
      final res = await http.post(
        Uri.parse("https://requrr-web-v2.vercel.app/api/payment/create-order"),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'planId': planId,
          'couponCode': code,
          'userCurrency': isIndia ? 'INR' : 'USD',
        }),
      );

      final data = json.decode(res.body);
      if (data['error'] != null) {
        setState(() {
          _couponValidation[planId.toString()] = 'error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'])),
        );
      } else {
        setState(() {
          _couponValidation[planId.toString()] = 'success';
          _discountedPrices[planId.toString()] = isIndia 
              ? data['finalPrice'] 
              : data['localPrice'];
        });
      }
      
      setState(() {
        _showCouponPopup[planId.toString()] = false;
      });
    } catch (err) {
      print('Coupon validation error: $err');
      setState(() {
        _couponValidation[planId.toString()] = 'error';
      });
    }
  }

  Future<void> handlePayment(int planId, double price, String planName, {String couponCode = ''}) async {
    final res = await http.post(
      Uri.parse("https://requrr-web-v2.vercel.app/api/payment/create-order"),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'planId': planId,
        'couponCode': couponCode,
        'userCurrency': isIndia ? 'INR' : 'USD',
      }),
    );

    final data = json.decode(res.body);
    if (data['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'])),
      );
      return;
    }

    _currentVerifyingPlanId = planId;
    final finalPriceValue = isIndia 
        ? (data['finalPrice'] is String 
            ? double.tryParse(data['finalPrice']) ?? 0.0 
            : (data['finalPrice'] as num).toDouble())
        : (data['localPrice'] is String 
            ? double.tryParse(data['localPrice']) ?? 0.0 
            : (data['localPrice'] as num).toDouble());
    
    _currentFinalPrice = finalPriceValue;

    _razorpay.open({
      'key': 'rzp_live_BmgvyhxY60MPaw', // Use live key from web
      'amount': data['amount'], // INR in paise
      'currency': data['localCurrency'] ?? 'INR',
      'name': 'Income Tracker',
      'description': '$planName Plan - $currencySymbol${(data['localPrice'] is String ? double.tryParse(data['localPrice']) ?? 0.0 : (data['localPrice'] as num).toDouble()).toStringAsFixed(2)} ${data['localCurrency']}/year',
      'order_id': data['id'],
      'prefill': {
        'contact': '',
        'email': '',
      },
      'theme': {'color': '#3399cc'},
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Get the coupon code for the current plan
    final couponCode = _couponInputs[_currentVerifyingPlanId.toString()] ?? '';
    
    final verifyRes = await http.post(
      Uri.parse("https://requrr-web-v2.vercel.app/api/payment/verify"),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'plan_id': _currentVerifyingPlanId,
        'coupon_code': couponCode,
        'final_price': _currentFinalPrice,
        'currency': 'INR',
      }),
    );

    final result = json.decode(verifyRes.body);
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Payment successful!')),
      );
      // Force refresh the subscription data
      await fetchData();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wallet selected: ${response.walletName}')),
    );
  }

  void _handleCouponChange(int planId, String value) {
    setState(() {
      _couponInputs[planId.toString()] = value;
    });
  }

  Widget buildPlanCard(Map<String, dynamic> plan, int index) {
    final planId = plan['id'] ?? index;
    final basePrice = isIndia
        ? (double.tryParse(plan['price_inr']?.toString() ?? '') ?? 0)
        : (double.tryParse(plan['price_usd']?.toString() ?? '') ?? 0);

    final finalPrice = _discountedPrices[planId.toString()] ?? basePrice;
    final isCurrentPlan = currentPlan != null && currentPlan!['plan_name'] == plan['name'];
    final isSubscribed = currentPlan != null;
    final currentPrice = currentPlan?['price'] ?? 0;
    final isUpgrade = !isSubscribed || basePrice > currentPrice;
    final disableButton = isCurrentPlan || !isUpgrade;

    final couponCode = _couponInputs[planId.toString()] ?? '';
    final validated = _couponValidation[planId.toString()];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Show star icons according to plan
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              plan['name'] == 'Free' ? 1 : plan['name'] == 'Monthly' ? 2 : 3,
              (index) => const Icon(Icons.star, size: 30, color: Colors.amber),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            plan['name'] ?? '',
            style: GoogleFonts.questrial(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            plan['description'] ?? '',
            style: GoogleFonts.questrial(
              fontSize: 14,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currencySymbol,
                style: GoogleFonts.questrial(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                finalPrice.toStringAsFixed(2),
                style: GoogleFonts.questrial(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          // Removed the '/month' text as we are showing full amount
          // Text(
          //   '/month',
          //   style: const TextStyle(fontSize: 14, color: Colors.grey),
          // ),
          const SizedBox(height: 8),
          // Removed the billed annually text as per user request
          // Text(
          //   '[ Billed Annually at $currencySymbol${finalPrice.toStringAsFixed(2)} ]',
          //   style: const TextStyle(fontSize: 12, color: Colors.grey),
          // ),
          const SizedBox(height: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureItem(plan['max_renewals'] == null 
                  ? 'Unlimited renewals' 
                  : '${plan['max_renewals']} renewals per year'),
              _buildFeatureItem('Unlimited forms and surveys'),
              _buildFeatureItem('Basic form creation tools'),
              _buildFeatureItem('Email support'),
            ],
          ),
          const SizedBox(height: 30),
          
          // Coupon functionality
          if (!isCurrentPlan && !disableButton && !(_showCouponPopup[planId.toString()] ?? false))
            GestureDetector(
              onTap: () {
                setState(() {
                  _showCouponPopup[planId.toString()] = true;
                });
              },
              child: Text(
                '+ Add Coupon Code',
                style: GoogleFonts.questrial(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          
          if (!isCurrentPlan && (_showCouponPopup[planId.toString()] ?? false))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coupon Code', style: TextStyle(fontSize: 12)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Enter coupon code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) => _handleCouponChange(planId, value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handleValidateCoupon(planId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Apply', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (validated == 'success')
            const Text(
              'Coupon applied successfully! 🎉',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          if (validated == 'error')
            const Text(
              'Invalid or expired coupon 😞',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),

          const SizedBox(height: 20),
          if (isCurrentPlan)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Your Current Plan",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: disableButton 
                    ? null 
                    : () => handlePayment(
                        planId, 
                        finalPrice, 
                        plan['name'] ?? '', 
                        couponCode: couponCode
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: disableButton ? Colors.grey : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  disableButton
                      ? 'Not Available'
                      : 'Subscribe ${currencySymbol}${finalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.questrial(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
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
        title: const Text("Pricing Plans", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                
                
                const SizedBox(height: 30),
                ...plans.asMap().entries.map((entry) => 
                  buildPlanCard(entry.value, entry.key)
                ).toList(),
              ],
            ),
    );
  }
}
