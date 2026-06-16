import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class QuestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final String userRole;

  const QuestionDetailScreen({
    super.key,
    required this.questionData,
    required this.userRole,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  // For student submission
  final _answerController = TextEditingController();
  String? _selectedOption;
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
        Uri.parse('${ApiConfig.baseUrl}/api/questions/${widget.questionData['Id'] ?? widget.questionData['id']}/submissions/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _mySubmission = data;
          if (data != null && data['AnswerText'] != null) {
            _answerController.text = data['AnswerText'];
            _selectedOption = data['AnswerText'];
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

  Future<void> _submitAnswer() async {
    final type = widget.questionData['Type'] ?? widget.questionData['type'] ?? 'short_answer';
    final answer = type == 'multiple_choice' ? _selectedOption : _answerController.text.trim();

    if (answer == null || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an answer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final token = await _getToken();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/questions/${widget.questionData['Id'] ?? widget.questionData['id']}/submissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'answerText': answer,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Answer submitted successfully!'),
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
        Uri.parse('${ApiConfig.baseUrl}/api/questions/${widget.questionData['Id'] ?? widget.questionData['id']}/submissions'),
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
                submission['Id'] ?? submission['id'],
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
    final dueDate = DateTime.tryParse(widget.questionData['DueDate'] ?? widget.questionData['dueDate'] ?? '');
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header
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
                          backgroundColor: Colors.purple.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.questionData['Title'] ?? widget.questionData['title'] ?? 'Untitled Question',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'by ${widget.questionData['creatorName'] ?? 'Teacher'}',
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
                    if (widget.questionData['Description'] != null &&
                        widget.questionData['Description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        widget.questionData['Description'],
                        style: const TextStyle(fontSize: 15, height: 1.5),
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
                  'Answer Submitted — Waiting for grade',
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
          hasSubmitted ? 'Update Your Answer' : 'Your Answer',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Answer input
        if ((widget.questionData['Type'] ?? widget.questionData['type']) == 'multiple_choice')
          ..._buildMultipleChoiceOptions(hasSubmitted)
        else
          TextField(
            controller: _answerController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        
        const SizedBox(height: 24),

        // Submit button
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitAnswer,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(hasSubmitted ? 'Update Answer' : 'Submit Answer'),
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

  List<Widget> _buildMultipleChoiceOptions(bool hasSubmitted) {
    final optionsRaw = widget.questionData['Options'] ?? widget.questionData['options'];
    List<String> options = [];
    if (optionsRaw is List) {
      options = optionsRaw.map((e) => e.toString()).toList();
    }

    if (options.isEmpty) {
      return [const Text('No options available.', style: TextStyle(color: Colors.red))];
    }

    return options.map((option) {
      return RadioListTile<String>(
        title: Text(option),
        value: option,
        groupValue: _selectedOption,
        onChanged: (String? value) {
          setState(() {
            _selectedOption = value;
          });
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: _selectedOption == option ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        activeColor: Colors.blue,
      );
    }).map((widget) => Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: widget,
    )).toList();
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
              'Student Answers',
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
                    'No answers yet',
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
