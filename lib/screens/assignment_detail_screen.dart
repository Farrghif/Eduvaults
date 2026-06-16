import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> assignmentData;
  final String userRole;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentData,
    required this.userRole,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  // For student submission
  final _answerController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  Map<String, dynamic>? _mySubmission;
  bool _loadingMySubmission = true;

  // For teacher grading
  List<dynamic> _submissions = [];
  bool _loadingSubmissions = true;

  @override
  void initState() {
    super.initState();
    if (widget.userRole == 'student') {
      _fetchMySubmission();
    } else {
      _fetchAllSubmissions();
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ======================== STUDENT FUNCTIONS ========================

  Future<void> _fetchMySubmission() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/assignments/${widget.assignmentData['Id']}/submissions/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _mySubmission = data;
          if (data != null && data['AnswerText'] != null) {
            _answerController.text = data['AnswerText'];
          }
          _loadingMySubmission = false;
        });
      } else {
        setState(() => _loadingMySubmission = false);
      }
    } catch (e) {
      setState(() => _loadingMySubmission = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitAssignment() async {
    if (_answerController.text.trim().isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an answer or upload a file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final token = await _getToken();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/assignments/${widget.assignmentData['Id']}/submissions');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      if (_answerController.text.trim().isNotEmpty) {
        request.fields['answerText'] = _answerController.text.trim();
      }

      if (_selectedFile != null && _selectedFile!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _selectedFile!.bytes!,
          filename: _selectedFile!.name,
          contentType: MediaType('application', 'octet-stream'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchMySubmission();
        }
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Submission failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ======================== TEACHER FUNCTIONS ========================

  Future<void> _fetchAllSubmissions() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/assignments/${widget.assignmentData['Id']}/submissions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _submissions = json.decode(response.body);
          _loadingSubmissions = false;
        });
      } else {
        setState(() => _loadingSubmissions = false);
      }
    } catch (e) {
      setState(() => _loadingSubmissions = false);
    }
  }

  Future<void> _gradeSubmission(int submissionId, int grade, String feedback) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/submissions/$submissionId/grade'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'grade': grade, 'feedback': feedback}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grade saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchAllSubmissions();
        }
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Failed to save grade';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGradeDialog(Map<String, dynamic> submission) {
    final gradeController = TextEditingController(
      text: submission['Grade']?.toString() ?? '',
    );
    final feedbackController = TextEditingController(
      text: submission['Feedback'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grade - ${submission['studentName']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show student's answer
              if (submission['AnswerText'] != null && submission['AnswerText'].toString().isNotEmpty) ...[
                const Text('Student Answer:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(submission['AnswerText']),
                ),
                const SizedBox(height: 12),
              ],
              // Show file info
              if (submission['FilePath'] != null && submission['FilePath'].toString().isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'File: ${submission['FilePath']}',
                        style: const TextStyle(color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(
                  labelText: 'Grade (0-100)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final grade = int.tryParse(gradeController.text);
              if (grade == null || grade < 0 || grade > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid grade (0-100)'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _gradeSubmission(
                submission['Id'],
                grade,
                feedbackController.text.trim(),
              );
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  // ======================== BUILD ========================

  @override
  Widget build(BuildContext context) {
    final dueDate = DateTime.tryParse(widget.assignmentData['DueDate'] ?? '');
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Header
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.assignment,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.assignmentData['Title'] ?? 'Untitled',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'by ${widget.assignmentData['creatorName'] ?? 'Teacher'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Due date
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: isOverdue ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dueDate != null
                                ? 'Due: ${DateFormat('dd MMM yyyy, HH:mm').format(dueDate)}'
                                : 'No due date',
                            style: TextStyle(
                              color: isOverdue ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Description
                    if (widget.assignmentData['Description'] != null &&
                        widget.assignmentData['Description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Linkify(
                        onOpen: (link) async {
                          final uri = Uri.parse(link.url);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch URL')),
                              );
                            }
                          }
                        },
                        text: widget.assignmentData['Description'],
                        style: const TextStyle(fontSize: 15, height: 1.5),
                        linkStyle: const TextStyle(color: Colors.blue),
                      ),
                    ],
                    // File Attachment
                    if (widget.assignmentData['FilePath'] != null &&
                        widget.assignmentData['FilePath'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse('${ApiConfig.baseUrl}/api/uploads/${widget.assignmentData['FilePath']}');
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open file')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.blue.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Attached File: ${widget.assignmentData['FilePath']}',
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Role-specific content
            if (widget.userRole == 'student') _buildStudentSection(),
            if (widget.userRole == 'teacher') _buildTeacherSection(),
          ],
        ),
      ),
    );
  }

  // ======================== STUDENT VIEW ========================

  Widget _buildStudentSection() {
    if (_loadingMySubmission) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool hasSubmitted = _mySubmission != null;
    final bool isGraded = hasSubmitted && _mySubmission!['Grade'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status banner
        if (isGraded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Grade: ${_mySubmission!['Grade']}/100',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (_mySubmission!['Feedback'] != null && _mySubmission!['Feedback'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Feedback: ${_mySubmission!['Feedback']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          )
        else if (hasSubmitted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.done, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Submitted — Waiting for grade',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        Text(
          hasSubmitted ? 'Update Your Submission' : 'Your Submission',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Answer text field
        TextField(
          controller: _answerController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write your answer here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // File picker
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.attach_file),
          label: Text(_selectedFile != null ? _selectedFile!.name : 'Attach file'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_selectedFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!.name,
                    style: const TextStyle(color: Colors.blue),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedFile = null),
                ),
              ],
            ),
          ),

        // Show previously submitted file
        if (hasSubmitted &&
            _mySubmission!['FilePath'] != null &&
            _mySubmission!['FilePath'].toString().isNotEmpty &&
            _selectedFile == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Previously submitted: ${_mySubmission!['FilePath']}',
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Submit button
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitAssignment,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(hasSubmitted ? 'Update Submission' : 'Submit'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // ======================== TEACHER VIEW ========================

  Widget _buildTeacherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Student Submissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _fetchAllSubmissions,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingSubmissions)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_submissions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No submissions yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          ..._submissions.map((sub) => _buildSubmissionCard(sub)),
      ],
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final isGraded = submission['Grade'] != null;
    final submittedAt = DateTime.tryParse(submission['SubmittedAt'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGradeDialog(submission),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isGraded
                        ? Colors.green.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(
                      (submission['studentName'] ?? 'S')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isGraded
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission['studentName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          submittedAt != null
                              ? 'Submitted: ${DateFormat('dd MMM yyyy, HH:mm').format(submittedAt)}'
                              : 'Submitted',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isGraded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${submission['Grade']}/100',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Grade',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              // Show answer preview
              if (submission['AnswerText'] != null && submission['AnswerText'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    submission['AnswerText'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              ],
              // Show file indicator
              if (submission['FilePath'] != null && submission['FilePath'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'File attached',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
