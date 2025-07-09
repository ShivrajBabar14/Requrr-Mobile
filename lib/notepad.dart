import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NotepadPage(
        id: '12345',
        client_name: 'B-102, Sector 10, Delhi',
        notes: 'Initial notes from dashboard', // Example note passed here
      ),
    );
  }
}

class NotepadPage extends StatefulWidget {
  final String id;
  final String client_name;
  final String? notes;

  const NotepadPage({
    Key? key,
    required this.id,
    required this.client_name,
    this.notes, // Optional notes passed here
  }) : super(key: key);

  @override
  _NotepadPageState createState() => _NotepadPageState();
}

class _NotepadPageState extends State<NotepadPage> {
  TextEditingController _controller = TextEditingController();
  TextStyle _currentTextStyle = GoogleFonts.questrial(fontSize: 18.0);

  @override
  void initState() {
    super.initState();
    // If notes are passed, initialize the text controller with those notes
    if (widget.notes != null) {
      _controller.text = widget.notes!;
    } else {
      _loadSavedText(); // If no notes passed, load from API
    }
  }

  Future<void> _loadSavedText() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    try {
      final getResponse = await http.get(
        Uri.parse(
          "https://api.camrilla.com/order/assignment?id=${widget.id}",
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (getResponse.statusCode == 200) {
        final assignmentData = json.decode(getResponse.body);
        final note = assignmentData['data'][0]['assignmentNote'] ?? '';

        setState(() {
          _controller.text = note;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load assignment (${getResponse.statusCode})',
              style: GoogleFonts.questrial(),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.questrial())),
      );
    }
  }

  Future<void> _saveText() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    try {
      final getResponse = await http.get(
        Uri.parse(
          "https://api.camrilla.com/order/assignment?id=${widget.id}",
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (getResponse.statusCode == 200) {
        final fullResponse = json.decode(getResponse.body);
        final data = fullResponse['data'][0];

        final updatedAssignment = {
          "customerName": data['customerName'],
          "customerMobile": data['customerMobile'],
          "customerEmail": data['customerEmail'],
          "customerAddress": data['customerAddress'],
          "assignmentAddress": data['assignmentAddress'],
          "assignmentName": data['assignmentName'],
          "assignmentDateTime": data['assignmentDateTime'],
          "assignmentStatus": data['assignmentStatus'],
          "contactPerson1Name": data['contactPerson1Name'],
          "contactPerson1Mobile": data['contactPerson1Mobile'],
          "contactPerson2Name": data['contactPerson2Name'],
          "contactPerson2Mobile": data['contactPerson2Mobile'],
          "assignToName": data['assignToName'],
          "assignToHandle": data['assignToHandle'],
          "assignmentNote": _controller.text,
          "totalAmount": data['totalAmount'],
          "reminderBeforedays": data['reminderBeforedays'],
          "reminderDate": data['reminderDate'],
          "id": data['id'],
        };

        final putResponse = await http.put(
          Uri.parse(
            "https://api.camrilla.com/order/assignment/${widget.id}",
          ),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(updatedAssignment),
        );

        if (putResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Note updated successfully',
                style: GoogleFonts.questrial(),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update note (${putResponse.statusCode})',
                style: GoogleFonts.questrial(),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load assignment (${getResponse.statusCode})',
              style: GoogleFonts.questrial(),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.questrial())),
      );
    }
  }

  void _clearText() {
    setState(() {
      _controller.clear();
    });
  }

  void _toggleBold() {
    setState(() {
      _currentTextStyle = _currentTextStyle.copyWith(
        fontWeight: _currentTextStyle.fontWeight == FontWeight.bold
            ? FontWeight.normal
            : FontWeight.bold,
      );
    });
  }

  void _toggleItalic() {
    setState(() {
      _currentTextStyle = _currentTextStyle.copyWith(
        fontStyle: _currentTextStyle.fontStyle == FontStyle.italic
            ? FontStyle.normal
            : FontStyle.italic,
      );
    });
  }

  void _toggleUnderline() {
    setState(() {
      _currentTextStyle = _currentTextStyle.copyWith(
        decoration: _currentTextStyle.decoration == TextDecoration.underline
            ? TextDecoration.none
            : TextDecoration.underline,
      );
    });
  }

  void _addBulletPoint() {
    final currentText = _controller.text;
    _controller.text = "$currentText• ";
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notes', style: GoogleFonts.questrial()),
            Text(
              widget.client_name,
              style: GoogleFonts.questrial(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [IconButton(icon: Icon(Icons.check), onPressed: _saveText)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Start typing here...',
                  hintStyle: GoogleFonts.questrial(),
                  border: InputBorder.none,
                ),
                style: _currentTextStyle,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.format_bold),
                  onPressed: _toggleBold,
                ),
                IconButton(
                  icon: Icon(Icons.format_italic),
                  onPressed: _toggleItalic,
                ),
                IconButton(
                  icon: Icon(Icons.format_underlined),
                  onPressed: _toggleUnderline,
                ),
                IconButton(
                  icon: Icon(Icons.format_list_bulleted),
                  onPressed: _addBulletPoint,
                ),
                IconButton(icon: Icon(Icons.clear), onPressed: _clearText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
