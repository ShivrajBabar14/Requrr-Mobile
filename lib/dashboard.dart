import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'sidebar.dart';
// import 'addassignment.dart';
// import 'details.dart';
import 'notepad.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import 'addpayment.dart';
// import 'professional.dart';
// import 'register.dart';
import 'auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'leads.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'login.dart';
// import 'package:flutter/services.dart';

void main() {
  runApp(const Dashboard());
}

class Dashboard extends StatefulWidget {
  final String? token;
  const Dashboard({super.key, this.token});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String? aToken;
  DateTime selectedDate = DateTime.now();
  DateTime currentMonth = DateTime.now();
  bool isExpanded = false;
  late PageController _pageController;
  int _initialPage = 0;
  final int _baseYear = 1970;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> incomeRecords = [];
  bool isLoading = true;
  bool isCalendarVisible = false;
  bool selectedDateOnlyPicked = false;
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  bool showYearView = true;
  bool isYearView = false;
  List<int> yearList = List.generate(
    100,
    (index) => 1970 + index,
  ); // Example: 1970–2069
  List<Map<String, dynamic>> selectedDayItems = [];
  List<Map<String, dynamic>> selectedCards = [];
  Map<String, dynamic>? selectedCardData;
  late ScrollController _yearScrollController;

  String?
  selectedFunctionId; // Track selected function id for showing info card

  bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonMap = json.decode(decoded);

      if (jsonMap['exp'] == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        jsonMap['exp'] * 1000,
      );
      return expiryDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Stats variables
  int totalRecords = 0;
  double totalAmount = 0;
  double paymentReceived = 0;
  double duePayment = 0;
  List<dynamic> recordDetails = [];
  List<dynamic> paymentDetails = [];
  List<dynamic> getRecordsForSelectedDate() {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return incomeRecords.where((record) {
      if (record['payment_date'] != null) {
        final paymentDate = DateTime.parse(record['payment_date']);
        if (DateFormat('yyyy-MM-dd').format(paymentDate) == selectedDateStr) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  @override
  void initState() {
    super.initState();
    _yearScrollController = ScrollController();
    _initializeToken();
    aToken = widget.token ?? '';

    // Calculate initial page based on current year and month relative to base year
    _initialPage =
        (DateTime.now().year - _baseYear) * 12 + (DateTime.now().month - 1);
    _pageController = PageController(initialPage: _initialPage);

    currentMonth = DateTime.now(); // ✅ Set current month

    // 🔧 PageController listener
    _pageController.addListener(() {
      if (_pageController.page != null) {
        int pageIndex = _pageController.page!.round();

        int newYear = _baseYear + (pageIndex ~/ 12);
        int newMonth = (pageIndex % 12) + 1;

        DateTime newCurrentMonth = DateTime(newYear, newMonth);

        if (newCurrentMonth.year != currentMonth.year ||
            newCurrentMonth.month != currentMonth.month) {
          setState(() {
            currentMonth = newCurrentMonth;
          });
          fetchRenewals(date: currentMonth);
        }
      }
    });

    // ✅ Immediately fetch assignments for current month
    fetchRenewals(date: currentMonth);
  }

  Future<void> _initializeToken() async {
    if (widget.token != null) {
      aToken = widget.token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      aToken = prefs.getString('auth_token');
    }
    print('Initialized token: ${aToken != null ? "exists" : "null"}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _yearScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedYear() {
    final selectedIndex = yearList.indexOf(currentMonth.year);
    if (selectedIndex != -1) {
      // Delay to ensure the widget is rendered before scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _yearScrollController.animateTo(
          selectedIndex * 60.0, // 60.0 is an estimated item width incl. spacing
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Future<void> fetchRenewals({DateTime? date, bool isYearView = false}) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get token from SharedPreferences if not available
      if (aToken == null || aToken!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        aToken = prefs.getString('auth_token');
      }

      // Validate token
      if (!isTokenValid(aToken)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
        return;
      }

      final trimmedToken = aToken!.trim();
      print('Using token: ${trimmedToken.substring(0, 10)}...');

      // Try both with and without www subdomain for income records
      final urls = [
        'https://requrr.com/api/income_records/upcoming',
        'https://www.requrr.com/api/income_records/upcoming',
      ];

      http.Response? response;
      Exception? lastError;

      for (final url in urls) {
        try {
          print('Trying URL: $url');
          response = await http
              .get(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $trimmedToken',
                  'Accept': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) break;
        } catch (e) {
          lastError = e as Exception;
          print('Error with $url: $e');
        }
      }

      if (response == null) {
        throw lastError ?? Exception('No response from server');
      }

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> assignmentsList = responseData is List
            ? responseData
            : [];

        // For each assignment, fetch client details and add company_name
        for (var assignment in assignmentsList) {
          try {
            final clientId = assignment['client_id'];
            if (clientId != null) {
              print('Client API call token: ${trimmedToken}');

              // Try both with and without www subdomain for client API
              final clientUrls = [
                'https://requrr.com/api/clients/$clientId',
                'https://www.requrr.com/api/clients/$clientId',
              ];

              http.Response? clientResponse;
              for (final clientUrl in clientUrls) {
                try {
                  clientResponse = await http
                      .get(
                        Uri.parse(clientUrl),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $trimmedToken',
                          'Accept': 'application/json',
                        },
                      )
                      .timeout(const Duration(seconds: 5));

                  if (clientResponse.statusCode == 200) break;
                } catch (e) {
                  print('Error with client URL $clientUrl: $e');
                }
              }

              if (clientResponse == null) {
                throw Exception('No response from client API');
              }

              print('Client API response status: ${clientResponse.statusCode}');
              print('Client API response headers: ${clientResponse.headers}');

              if (clientResponse.statusCode == 200) {
                final clientData = json.decode(clientResponse.body);
                print('Client data for clientId $clientId: $clientData');
                assignment['company_name'] = clientData['company_name'] ?? '';
                print('Assigned company_name: ${assignment['company_name']}');
              } else {
                assignment['company_name'] = '';
                print(
                  'Failed to fetch client data for clientId $clientId, status: ${clientResponse.statusCode}',
                );
                // If unauthorized, try to refresh token or log out
                if (clientResponse.statusCode == 401) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('auth_token');
                  throw Exception('Session expired');
                }
              }
            } else {
              assignment['company_name'] = '';
              print('No client_id found for assignment ${assignment['id']}');
            }
          } catch (e) {
            print(
              'Error fetching client data for assignment ${assignment['id']}: $e',
            );
            assignment['company_name'] = '';
            // If it's an unauthorized error, propagate it
            if (e.toString().contains('Session expired')) {
              throw e;
            }
          }
        }

        setState(() {
          incomeRecords = assignmentsList;
        });
      } else if (response.statusCode == 401) {
        // Clear stored token on 401
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        throw Exception('Session expired');
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchRenewals: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));

      if (e.toString().contains('Session expired')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Map<String, List<dynamic>> _groupRenewalsByDate(List<dynamic> renewals) {
    Map<String, List<dynamic>> grouped = {};

    for (var renewal in renewals) {
      if (renewal['due_date'] != null) {
        try {
          DateTime dueDate = DateTime.parse(renewal['due_date']);
          String dateKey = DateFormat('dd MMM yyyy').format(dueDate);

          if (!grouped.containsKey(dateKey)) {
            grouped[dateKey] = [];
          }
          grouped[dateKey]!.add(renewal);
        } catch (e) {
          print("Error parsing date: $e");
        }
      }
    }

    // Sort the map by date (convert to DateTime for proper sorting)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        try {
          DateTime dateA = DateFormat('dd MMM yyyy').parse(a);
          DateTime dateB = DateFormat('dd MMM yyyy').parse(b);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

    Map<String, List<dynamic>> sortedMap = {};
    for (var key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }

    return sortedMap;
  }

  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black, // 🔴 Red status bar
        statusBarIconBrightness: Brightness.light, // Light icons (optional)
      ),
    );

    final groupedRenewals = _groupRenewalsByDate(incomeRecords);

    return WillPopScope(
      onWillPop: () async {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        } else {
          exit(0);
        }
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: Sidebar(
          token: aToken,
          onYearSelected: (selectedYear) {
            setState(() {
              currentMonth = DateTime(selectedYear);
              isYearView = true;
              isCalendarVisible = true;
            });
            fetchRenewals(date: DateTime(selectedYear), isYearView: true);
          },
          onMonthSelected: () {
            setState(() {
              isYearView = false;
              isCalendarVisible = true;
              // Jump to the page corresponding to currentMonth in the PageView
              int pageIndex =
                  (currentMonth.year - _baseYear) * 12 +
                  (currentMonth.month - 1);
              _pageController.jumpToPage(pageIndex);
            });
            fetchRenewals(date: currentMonth, isYearView: false);
          },
          onLogout: () {
            setState(() {
              aToken = null;
              // assignments.clear();
              selectedDayItems.clear();
              selectedCards.clear();
              // assignmentDetails.clear();
              paymentDetails.clear();
              // totalAssignments = 0;
              // totalCost = 0;
              paymentReceived = 0;
              duePayment = 0;
              selectedCardData = null;
              selectedDateOnlyPicked = false;
              isCalendarVisible = false;
              isYearView = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have been logged out')),
            );
          },
        ),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Text(
            selectedDateOnlyPicked
                ? DateFormat('dd MMM yyyy').format(selectedDate)
                : "Upcoming Renewals",
            style: GoogleFonts.questrial(color: Colors.black, fontSize: 15),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: isCalendarVisible ? 0 : 4,
          shadowColor: Colors.grey.withOpacity(0.5),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  isCalendarVisible = !isCalendarVisible;
                });
              },
              child: Row(
                children: [
                  Text(
                    isYearView
                        ? DateFormat("yyyy").format(currentMonth)
                        : DateFormat("MMM yyyy").format(currentMonth),
                    style: GoogleFonts.questrial(
                      color: Colors.black,
                      fontSize: 15,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (isCalendarVisible)
              isYearView ? _buildYearCalendar() : _buildCalendar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (incomeRecords.isEmpty)
                      Center(
                        child: Text(
                          "No upcoming renewals found",
                          style: GoogleFonts.questrial(color: Colors.grey),
                        ),
                      )
                    else if (selectedDateOnlyPicked)
                      // Show renewals for selected date
                      Column(
                        children: [
                          // Date header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: GoogleFonts.questrial(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // Renewals for selected date
                          ...incomeRecords
                              .where((record) {
                                if (record['due_date'] != null) {
                                  try {
                                    DateTime dueDate = DateTime.parse(
                                      record['due_date'],
                                    );
                                    return DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(dueDate) ==
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(selectedDate);
                                  } catch (e) {
                                    return false;
                                  }
                                }
                                return false;
                              })
                              .map((record) => _renewalsItem(record))
                              .toList(),
                        ],
                      )
                    else if (isYearView)
                      // Show renewals for selected year
                      Column(
                        children: [
                          // Year header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Renewals for $selectedYear',
                              style: GoogleFonts.questrial(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // Renewals for selected year
                          ...incomeRecords
                              .where((record) {
                                if (record['due_date'] != null) {
                                  try {
                                    DateTime dueDate = DateTime.parse(
                                      record['due_date'],
                                    );
                                    return dueDate.year == selectedYear;
                                  } catch (e) {
                                    return false;
                                  }
                                }
                                return false;
                              })
                              .map((record) => _renewalsItem(record))
                              .toList(),
                        ],
                      )
                    else
                      // Default view - show all renewals grouped by date
                      ..._groupRenewalsByDate(incomeRecords).entries.expand((
                        entry,
                      ) {
                        return [
                          // Date header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              entry.key,
                              style: GoogleFonts.questrial(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // Renewals for this date
                          ...entry.value.map((record) => _renewalsItem(record)),
                        ];
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            currentIndex: 0,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: GoogleFonts.questrial(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.questrial(
              fontWeight: FontWeight.normal,
              fontSize: 12,
            ),
            onTap: (index) {
              // if (index == 1) {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(builder: (context) => const Leads()),
              //   );
              // }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.miscellaneous_services_outlined),
                label: 'Services',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Clients',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renewalsItem(dynamic assignment) {
    String title = assignment['service_name']?.toString() ?? 'No Service';
    String name =
        assignment['client_name']?.toString() ?? 'Client Name Not Available';
    String notes = assignment['notes']?.toString() ?? 'No Notes';
    int daysUntilRenewal = 0;
    String amount = assignment['amount']?.toString() ?? 'No Amount';
    bool noPaymentAdded =
        assignment['amount'] == null || assignment['amount'] == "0";

    if (assignment['due_date'] != null) {
      try {
        DateTime dueDate = DateTime.parse(assignment['due_date']);
        DateTime currentDate = DateTime.now();
        daysUntilRenewal = dueDate.difference(currentDate).inDays;
      } catch (e) {
        print("Error parsing date: $e");
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Space between cards
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3), // Bottom shadow only
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotepadPage(
                  id: assignment['id'].toString(),
                  client_name:
                      assignment['client_name']?.toString() ?? 'No Client Name',
                  notes: notes,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.questrial(
                              fontSize: 14,
                              color: const Color(0xFF444444),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: GoogleFonts.questrial(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (noPaymentAdded)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No Payment',
                                style: GoogleFonts.questrial(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Right side content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Amount: $amount',
                          style: GoogleFonts.questrial(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: daysUntilRenewal <= 7
                                ? Colors.red
                                : Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$daysUntilRenewal days left',
                            style: GoogleFonts.questrial(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: const Offset(0, 5),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["S", "M", "T", "W", "T", "F", "S"]
                  .map(
                    (day) => Text(
                      day,
                      style: GoogleFonts.questrial(fontWeight: FontWeight.bold),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              itemCount: null, // Removed limit for infinite scrolling
              itemBuilder: (context, index) {
                int year = _baseYear + (index ~/ 12);
                int month = (index % 12) + 1;
                DateTime monthDate = DateTime(year, month);
                return _buildMonthCalendar(monthDate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    // Create a set of dates that have renewals for quick lookup
    Set<String> renewalDates = {};
    for (var record in incomeRecords) {
      if (record['due_date'] != null) {
        try {
          DateTime dueDate = DateTime.parse(record['due_date']);
          renewalDates.add(DateFormat('yyyy-MM-dd').format(dueDate));
        } catch (e) {
          print("Error parsing date: $e");
        }
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.7,
      ),
      itemCount:
          DateTime(month.year, month.month + 1, 0).day +
          DateTime(month.year, month.month, 1).weekday % 7,
      itemBuilder: (context, index) {
        int firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;

        if (index < firstWeekday) return const SizedBox();

        int dayNumber = index - firstWeekday + 1;
        DateTime day = DateTime(month.year, month.month, dayNumber);
        bool isToday =
            day.day == DateTime.now().day &&
            day.month == DateTime.now().month &&
            day.year == DateTime.now().year;
        bool isSelected = day.isAtSameMomentAs(selectedDate);
        bool hasRenewal = renewalDates.contains(
          DateFormat('yyyy-MM-dd').format(day),
        );

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedDate = day;
              isCalendarVisible = false;
              selectedDateOnlyPicked = true;
              selectedCards.clear();
              selectedCardData = null;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? Colors.black
                  : isSelected
                  ? Colors.grey
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              "$dayNumber",
              style: GoogleFonts.questrial(
                color: hasRenewal
                    ? Colors
                          .red // Red text for renewal dates
                    : isToday || isSelected
                    ? Colors
                          .white // White text for today/selected dates
                    : Colors.black, // Black text for normal dates
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearCalendar() {
    // Automatically scroll to the selected year
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedYear();
    });

    return AnimatedOpacity(
      opacity: isCalendarVisible ? 1.0 : 0.0,
      duration: const Duration(seconds: 2),
      onEnd: () {
        if (!isCalendarVisible) {
          // Optionally handle after fade-out completes
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              offset: const Offset(0, 5),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView.separated(
                controller: _yearScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                itemCount: yearList.length,
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final year = yearList[index];
                  final isSelected = year == currentMonth.year;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentMonth = DateTime(year);
                        isYearView = true;
                        isCalendarVisible = false;
                        selectedDateOnlyPicked = false; // Reset date selection
                        selectedYear = year; // Store the selected year
                      });
                      fetchRenewals(date: DateTime(year), isYearView: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$year',
                        style: GoogleFonts.questrial(
                          fontSize: 16,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
