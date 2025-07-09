import 'package:flutter/material.dart';
import 'registerform.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Registration())),
    );
  }
}

class Registration extends StatefulWidget {
  @override
  _RegistrationState createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  bool isLoading = false;

  Future<void> googleLogin() async {
    setState(() => isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);

      await googleSignIn.signOut(); // Prompt for fresh account
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Google Sign-in Cancelled")));
        return;
      }

      final fullName = account.displayName?.split(" ") ?? [];
      final firstName = fullName.isNotEmpty ? fullName.first : '';
      final lastName = fullName.length > 1 ? fullName.sublist(1).join(" ") : '';

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SignUpPage(
            firstName: firstName,
            lastName: lastName,
            email: account.email,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Registration Failed: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 98, 179, 250), Color.fromARGB(255, 0, 106, 255)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "“Organized Business is Profitable Business”\nGet Organized With Requrr!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.questrial(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Login",
                  style: GoogleFonts.questrial(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Already A Member",
                        style: GoogleFonts.questrial(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_right_alt, color: Colors.black),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "OR",
                  style: GoogleFonts.questrial(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SignUpPage()),
                          );
                        },
                  child: Text(
                    "New Member? Register Here",
                    style: GoogleFonts.questrial(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                // if (isLoading)
                //   CircularProgressIndicator(color: Colors.white)
                // else
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       GestureDetector(
                //         // onTap: facebookLogin,
                //         child: CircleAvatar(
                //           backgroundColor: Colors.white,
                //           radius: 22,
                //           child: Icon(
                //             Icons.facebook,
                //             color: Colors.blue,
                //             size: 30,
                //           ),
                //         ),
                //       ),
                //       SizedBox(width: 20),
                //       GestureDetector(
                //         onTap: googleLogin,
                //         child: CircleAvatar(
                //           backgroundColor: Colors.white,
                //           radius: 22,
                //           child: Image.network(
                //             "https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png",
                //             width: 30,
                //             height: 30,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                SizedBox(height: 10),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
