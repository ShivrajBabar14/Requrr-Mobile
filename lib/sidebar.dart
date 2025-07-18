import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'professional.dart';
// import 'setting.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'register.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'account.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    this.token,
    this.onYearSelected,
    this.onMonthSelected,
    this.onLogout, // Added onLogout callback
  });

  final String? token;
  final Function(int)? onYearSelected;
  final VoidCallback? onMonthSelected;
  final VoidCallback? onLogout; // Added onLogout callback

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late GoogleSignIn _googleSignIn;
  String? token;
  int assignmentCount = 0;
  String? userName;
  String? userPlan;
  String? profileImage;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(); // Initialize _googleSignIn here
    _loadAccessToken();
  }

  Future<String?> getGoogleProfileImage() async {
    try {
      // Attempt to sign in the user
      await _googleSignIn.signIn();

      // If signed in, fetch the profile image URL
      final GoogleSignInAccount? user = _googleSignIn.currentUser;
      if (user != null) {
        // Get the profile image URL
        return user.photoUrl;
      }
    } catch (error) {
      print("Google Sign-In Error: $error");
    }
    return null;
  }

  Future<void> _loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final userDataString = prefs.getString('userData');
    print("ACCESS TOKEN: $token");

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      print("Decoded token: $decodedToken");

      Map<String, dynamic> userData = {};
      if (userDataString != null) {
        userData = jsonDecode(userDataString);
      }

      final prettyUserData = const JsonEncoder.withIndent(
        '  ',
      ).convert(userData);
      final prettyDecodedToken = const JsonEncoder.withIndent(
        '  ',
      ).convert(decodedToken);

      print("🧾 Decoded JWT Token:\n$prettyDecodedToken");
      print("📦 User Data from SharedPreferences:\n$prettyUserData");

      setState(() {
        this.token = token;
        userName =
            '${userData["first_name"] ?? ""} ${userData["last_name"] ?? ""}'
                .trim();
        if (userName!.isEmpty) {
          userName = decodedToken["email"] ?? "User";
        }
        userEmail = userData["email"] ?? decodedToken['email'];
        profileImage = userData["profileImage"];
      });

      _fetchAssignmentCount(token);
      _fetchUserPlan(token);
    }
  }

  Future<void> _fetchUserPlan(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.requrr.com/api/me'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print(
          "User Plan API full response:\n${const JsonEncoder.withIndent('  ').convert(data)}",
        );

        setState(() {
          userName = "${data['first_name']} ${data['last_name']}".trim();
          userEmail = data['email'];
          // Set default plan name (you can update this if real plan info is elsewhere)
          userPlan = "Basic";
        });

        // Optionally store the fetched user info locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          "userData",
          jsonEncode({
            "first_name": data["first_name"],
            "last_name": data["last_name"],
            "email": data["email"],
            "profileImage": "", // Optional
          }),
        );
      } else {
        print("Failed to fetch user plan: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching user plan: $e");
    }
  }

  Future<void> _fetchAssignmentCount(String token) async {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    // Calculate last day of current month dynamically
    DateTime endDate = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(Duration(days: 1));
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.camrilla.com/order/assignment?'
          'startDate=${startDate.millisecondsSinceEpoch}'
          '&endDate=${endDate.millisecondsSinceEpoch}',
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['code'] == 0 && responseData['data'] != null) {
          setState(() {
            // Ensure data is a list and count only valid assignments
            if (responseData['data'] is List) {
              assignmentCount = responseData['data'].length;
            } else {
              assignmentCount = 0;
            }
          });
        } else {
          setState(() {
            assignmentCount = 0;
          });
        }
      } else {
        setState(() {
          assignmentCount = 0;
        });
      }
    } catch (e) {
      print("Error fetching assignment count: $e");
      setState(() {
        assignmentCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      child: Drawer(
        child: Column(
          children: [
            _buildHeader(context, userName, userPlan),

            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 16.0),
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (token != null) ...[
                            _buildDrawerItem(
                              context,
                              Icons.home,
                              "Assignment",
                              count: assignmentCount,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, "/assignment");
                              },
                            ),
                            if (userPlan == 'Basic') ...[
                              _buildDrawerItem(
                                context,
                                Icons.subscriptions,
                                "Subscription",
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, "/subscription");
                                },
                              ),
                            ],
                            _buildDrawerItem(
                              context,
                              Icons.feedback,
                              "Feedback",
                              onTap: () {
                                if (token != null) {
                                  showFeedbackDialog(context, token!);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please login first"),
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.smartphone,
                              "App Info",
                              onTap: () {
                                Navigator.pushNamed(context, "/appInfo");
                              },
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.settings,
                              "Settings",
                              onTap: () {},
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.thumb_up,
                              "Rate Us",
                              onTap: () {},
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.share,
                              "Share App",
                              onTap: () {},
                            ),
                          ] else ...[
                            _buildDrawerItem(
                              context,
                              Icons.smartphone,
                              "App Info",
                              onTap: () {
                                Navigator.pushNamed(context, "/appInfo");
                              },
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.thumb_up,
                              "Rate Us",
                              onTap: () {},
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.email,
                              "Contact Us",
                              onTap: () {},
                            ),
                            _buildDrawerItem(
                              context,
                              Icons.share,
                              "Share App",
                              onTap: () {},
                            ),
                            _buildDrawerItem(
                              context,
                              null,
                              "Login",
                              isLogout: false,
                              leadingIcon: SvgPicture.asset(
                                'assets/Login.svg',
                                width: 24,
                                height: 24,
                                color: Colors.red,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Future.delayed(
                                  const Duration(milliseconds: 250),
                                  () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Registration(),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (token != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        child: GestureDetector(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            setState(() {
                              token = null;
                            });

                            if (widget.onLogout != null) widget.onLogout!();

                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login', 
                              (Route<dynamic> route) => false,
                            );
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/Logout.svg',
                                  width: 20,
                                  height: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Log Out",
                                  style: GoogleFonts.questrial(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String? userName,
    String? userPlan,
  ) {
    String avatarUrl;

    if (profileImage != null && profileImage!.isNotEmpty) {
      avatarUrl = profileImage!;
    } else if (userEmail != null && userEmail!.contains('@gmail.com')) {
      final initials = (userName ?? 'U')
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
          .join();
      avatarUrl =
          'https://ui-avatars.com/api/?name=$initials&background=de512e&color=fff';
    } else {
      avatarUrl =
          'https://ui-avatars.com/api/?name=User&background=999&color=fff';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello,",
                      style: GoogleFonts.questrial(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      userName ?? "User",
                      style: GoogleFonts.questrial(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (userEmail != null)
                      Text(
                        userEmail!,
                        style: GoogleFonts.questrial(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData? icon,
    String title, {
    bool isLogout = false,
    int? count,
    VoidCallback? onTap,
    Widget? leadingIcon,
  }) {
    return ListTile(
      dense: true,
      leading:
          leadingIcon ??
          (icon != null
              ? Icon(icon, color: Colors.black) // Set icon color to black
              : const Icon(Icons.circle, color: Colors.transparent)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.questrial(fontSize: 15)),
          if (count != null)
            Text(
              count.toString(),
              style: GoogleFonts.questrial(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: onTap,
    );
  }

  void showFeedbackDialog(BuildContext context, String token) {
    TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Feedback & Suggestions",
                      style: GoogleFonts.questrial(
                        color: Colors.red,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  cursorColor: Colors.red,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "Write here",
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 5,
                    ),
                  ),
                ),
                Divider(color: Colors.grey, height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      String feedback = feedbackController.text.trim();

                      if (feedback.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please enter feedback")),
                        );
                        return;
                      }

                      try {
                        var url = Uri.parse(
                          "http://api.camrilla.com/user-feedback",
                        );
                        var response = await http.post(
                          url,
                          headers: {
                            "Content-Type": "application/json",
                            "Authorization": "Bearer $token",
                          },
                          body: jsonEncode({"feedback": feedback}),
                        );

                        Navigator.of(context).pop();

                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Feedback submitted successfully"),
                            ),
                          );
                        } else {
                          var resData = jsonDecode(response.body);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                resData["message"] ?? "Submission failed",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    child: Text(
                      "SUBMIT",
                      style: GoogleFonts.questrial(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
