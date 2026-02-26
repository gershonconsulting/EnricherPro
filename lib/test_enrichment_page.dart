import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TestEnrichmentPage extends StatefulWidget {
  const TestEnrichmentPage({Key? key}) : super(key: key);

  @override
  State<TestEnrichmentPage> createState() => _TestEnrichmentPageState();
}

class _TestEnrichmentPageState extends State<TestEnrichmentPage> {
  String _result = 'Click button to test enrichment';
  bool _isLoading = false;

  Future<void> _testEnrichment() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing enrichment...';
    });

    try {
      final response = await http.post(
        Uri.parse('/api/enrich/batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contacts': [
            {
              'firstname': 'Mark',
              'lastname': 'Vassella',
              'title': 'MD & CEO',
              'company': 'BlueScope',
              'linkedin_url': 'https://au.linkedin.com/in/mark-vassella-261b2771'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['results'][0];
        
        setState(() {
          _result = '''
✅ SUCCESS!

Response Status: ${response.statusCode}
Response Length: ${response.body.length} bytes

📊 Backend Response:
${JsonEncoder.withIndent('  ').convert(result)}

📧 Parsed Fields:
   Name: ${result['firstname']} ${result['lastname']}
   Email: ${result['email']}
   Confidence: ${result['email_confidence']}
   LinkedIn: ${result['linkedin_url']}
   Status: ${result['enrichment_status']}
          ''';
        });
      } else {
        setState(() {
          _result = '❌ Error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _result = '❌ Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrichment API Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Direct API Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testEnrichment,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Enrichment API'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
