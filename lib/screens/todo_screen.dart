import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';
import 'assignment_detail_screen.dart';

class TodoScreen extends StatefulWidget {
  final String userRole;

  const TodoScreen({super.key, required this.userRole});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.userRole == 'teacher' ? 2 : 3,
      vsync: this,
    );
    _fetchTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTodo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/todo'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _assignments = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == 'teacher' ? 'To Review' : 'To-Do'),
        bottom: TabBar(
          controller: _tabController,
          tabs: widget.userRole == 'teacher'
              ? const [
                  Tab(text: 'To Review'),
                  Tab(text: 'Reviewed'),
                ]
              : const [
                  Tab(text: 'Assigned'),
                  Tab(text: 'Missing'),
                  Tab(text: 'Done'),
                ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchTodo();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: widget.userRole == 'teacher'
                  ? [
                      _buildTeacherList(true), // To Review
                      _buildTeacherList(false), // Reviewed
                    ]
                  : [
                      _buildStudentList(['assigned']), // Assigned
                      _buildStudentList(['missing']), // Missing
                      _buildStudentList(['submitted', 'graded']), // Done
                    ],
            ),
    );
  }

  Widget _buildTeacherList(bool needsReview) {
    final filtered = _assignments.where((a) {
      final unreviewed = (a['needsReviewCount'] ?? 0) as int;
      return needsReview ? unreviewed > 0 : unreviewed == 0;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              needsReview ? 'No assignments to review!' : 'No reviewed assignments yet.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final a = filtered[index];
        return _buildAssignmentCard(a);
      },
    );
  }

  Widget _buildStudentList(List<String> statuses) {
    final filtered = _assignments.where((a) {
      return statuses.contains(a['submissionStatus']);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Woohoo, no work due in here!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final a = filtered[index];
        return _buildAssignmentCard(a);
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = DateTime.tryParse(assignment['DueDate'] ?? '');
    final status = assignment['submissionStatus'] as String?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignmentDetailScreen(
                assignmentData: assignment,
                userRole: widget.userRole,
              ),
            ),
          );
          _fetchTodo(); // Refresh on return
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.assignment,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['Title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment['ClassName'] ?? '',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueDate != null
                          ? 'Due: ${DateFormat('dd MMM yyyy, HH:mm').format(dueDate)}'
                          : 'No due date',
                      style: TextStyle(
                        color: status == 'missing' ? Colors.red : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    if (widget.userRole == 'teacher') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${assignment['submissionCount'] ?? 0} submitted'),
                          const SizedBox(width: 16),
                          if ((assignment['needsReviewCount'] ?? 0) > 0) ...[
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text('${assignment['needsReviewCount']} to review', style: const TextStyle(color: Colors.orange)),
                          ]
                        ],
                      ),
                    ] else if (status != null && status != 'assigned') ...[
                      const SizedBox(height: 8),
                      Text(
                        status == 'graded' 
                            ? 'Graded: ${assignment['Grade']}/100'
                            : status == 'submitted' 
                                ? 'Turned in' 
                                : 'Missing',
                        style: TextStyle(
                          color: status == 'graded' ? Colors.green : (status == 'missing' ? Colors.red : Colors.blue),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
