import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import 'assignment_detail_screen.dart';
import 'material_detail_screen.dart';
import 'question_detail_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String userRole;

  const ClassDetailScreen({
    super.key,
    required this.classData,
    required this.userRole,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  int _selectedIndex = 0;

  // Stream data
  List<dynamic> _announcements = [];
  bool _loadingAnnouncements = true;

  // Classwork data
  List<dynamic> _assignments = [];
  List<dynamic> _materials = [];
  List<dynamic> _questions = [];
  List<dynamic> _classworkItems = [];
  bool _loadingClasswork = true;

  // People data
  List<dynamic> _teachers = [];
  List<dynamic> _students = [];
  List<dynamic> _majors = [];
  bool _loadingPeople = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _fetchClasswork();
    _fetchMembers();
    _fetchMajors();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ======================== STREAM ========================

  Future<void> _fetchAnnouncements() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/announcements'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _announcements = json.decode(response.body);
          _loadingAnnouncements = false;
        });
      } else {
        setState(() => _loadingAnnouncements = false);
      }
    } catch (e) {
      setState(() => _loadingAnnouncements = false);
    }
  }

  Future<void> _postAnnouncement(String content) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/announcements'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'content': content}),
      );
      if (response.statusCode == 201) {
        await _fetchAnnouncements();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to post announcement')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ======================== CLASSWORK ========================

  Future<void> _fetchAssignments() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/assignments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _assignments = json.decode(response.body);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchMaterials() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/materials'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _materials = json.decode(response.body);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchQuestions() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/questions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _questions = json.decode(response.body);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchClasswork() async {
    setState(() => _loadingClasswork = true);
    await Future.wait([_fetchAssignments(), _fetchMaterials(), _fetchQuestions()]);
    
    final combined = [
      ..._assignments.map((a) => {...a, 'itemType': 'assignment'}),
      ..._materials.map((m) => {...m, 'itemType': 'material'}),
      ..._questions.map((q) => {...q, 'itemType': 'question'}),
    ];
    
    combined.sort((a, b) {
      final dateA = DateTime.tryParse(a['CreatedAt'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['CreatedAt'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _classworkItems = combined;
        _loadingClasswork = false;
      });
    }
  }

  Future<void> _createAssignment(String title, String description, DateTime dueDate, PlatformFile? file) async {
    final token = await _getToken();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/assignments');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['dueDate'] = dueDate.toIso8601String();
      
      if (file != null && file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: MediaType('application', 'octet-stream'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        await _fetchClasswork();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment created successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Failed';
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

  Future<void> _createMaterial(String title, PlatformFile? file) async {
    setState(() => _loadingClasswork = true);
    final token = await _getToken();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/materials');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = title;

      if (file != null && file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: MediaType('application', 'octet-stream'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        await _fetchClasswork();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Material uploaded!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Failed to upload';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
        }
        setState(() => _loadingClasswork = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
      setState(() => _loadingClasswork = false);
    }
  }

  Future<void> _createQuestion(String title, String description, DateTime dueDate, String type, List<String> options) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/questions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'description': description,
          'dueDate': dueDate.toIso8601String(),
          'type': type,
          'options': options,
        }),
      );
      if (response.statusCode == 201) {
        await _fetchClasswork();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question created successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Failed';
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

  // ======================== DELETE FUNCTIONS ========================

  Future<void> _deleteItem(String type, int id) async {
    final token = await _getToken();
    String url = '';
    if (type == 'announcement') url = '/api/announcements/$id';
    else if (type == 'assignment') url = '/api/assignments/$id';
    else if (type == 'question') url = '/api/questions/$id';
    else url = '/api/materials/$id';
    
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$url'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (type == 'announcement') _fetchAnnouncements();
        else _fetchClasswork();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ======================== CLASS SETTINGS ========================

  Future<void> _updateClass(String name, String desc) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': name, 'description': desc}),
      );
      if (response.statusCode == 200) {
        // Just show success, normally we'd update parent, but a re-fetch is better
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class updated'), backgroundColor: Colors.green));
          Navigator.pop(context); // Pop class details back to home to refresh
        }
      }
    } catch (e) {
      // Ignore for brevity
    }
  }

  Future<void> _deleteClass() async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class deleted'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {}
  }

  Future<void> _leaveClass() async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/leave'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left class successfully'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {}
  }

  // ======================== PEOPLE ========================

  Future<void> _fetchMembers() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/members'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _teachers = data['teachers'] ?? [];
          _students = data['students'] ?? [];
          _loadingPeople = false;
        });
      } else {
        setState(() => _loadingPeople = false);
      }
    } catch (error) {
      setState(() => _loadingPeople = false);
    }
  }

  Future<void> _fetchMajors() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/majors'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _majors = json.decode(response.body);
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _removeMember(int studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: const Text('Are you sure you want to remove this student from the class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/members/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student removed successfully'), backgroundColor: Colors.green),
          );
        }
        _fetchMembers();
      } else {
        if (mounted) {
          final error = json.decode(response.body)['message'] ?? 'Failed to remove student';
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

  // ======================== DIALOGS ========================

  void _showPostAnnouncementDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Announcement'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Share something with your class...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _postAnnouncement(controller.text.trim());
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _showCreateAssignmentDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 23, minute: 59);
    PlatformFile? selectedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Due: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                  subtitle: Text('at ${selectedTime.format(context)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                    if (context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setDialogState(() => selectedTime = time);
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles();
                    if (result != null) {
                      setDialogState(() => selectedFile = result.files.first);
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(selectedFile?.name ?? 'Attach file (optional)'),
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
                if (titleController.text.trim().isNotEmpty) {
                  final dueDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  Navigator.pop(context);
                  _createAssignment(
                    titleController.text.trim(),
                    descController.text.trim(),
                    dueDateTime,
                    selectedFile,
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMaterialDialog() {
    final titleController = TextEditingController();
    PlatformFile? selectedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title (required)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null) {
                    setDialogState(() => selectedFile = result.files.first);
                  }
                },
                icon: const Icon(Icons.attach_file),
                label: Text(selectedFile?.name ?? 'Attach file'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _createMaterial(titleController.text.trim(), selectedFile);
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateQuestionDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 23, minute: 59);
    String questionType = 'short_answer';
    List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: questionType,
                  decoration: const InputDecoration(
                    labelText: 'Question Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'short_answer', child: Text('Short Answer')),
                    DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => questionType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Question (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (questionType == 'multiple_choice') ...[
                  const SizedBox(height: 16),
                  const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.radio_button_unchecked, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              decoration: InputDecoration(
                                hintText: 'Option ${index + 1}',
                                isDense: true,
                              ),
                            ),
                          ),
                          if (optionControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  optionControllers[index].dispose();
                                  optionControllers.removeAt(index);
                                });
                              },
                            )
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        optionControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Due: ${DateFormat('dd MMM yyyy').format(selectedDate)}'),
                  subtitle: Text('at ${selectedTime.format(context)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                    if (context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setDialogState(() => selectedTime = time);
                      }
                    }
                  },
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
                if (titleController.text.trim().isNotEmpty) {
                  List<String> options = [];
                  if (questionType == 'multiple_choice') {
                    options = optionControllers
                        .map((c) => c.text.trim())
                        .where((text) => text.isNotEmpty)
                        .toList();
                    if (options.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please provide at least 2 options for multiple choice')),
                      );
                      return;
                    }
                  }
                  
                  final dueDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  Navigator.pop(context);
                  _createQuestion(
                    titleController.text.trim(),
                    descController.text.trim(),
                    dueDateTime,
                    questionType,
                    options,
                  );
                }
              },
              child: const Text('Ask'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClassSettings() {
    final nameController = TextEditingController(text: widget.classData['name']);
    final descController = TextEditingController(text: widget.classData['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Class Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Class Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateClass(nameController.text, descController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ======================== BUILD ========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['name'] ?? 'Class'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchAnnouncements();
              _fetchClasswork();
              _fetchMembers();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showClassSettings();
              if (value == 'delete') _deleteClass();
              if (value == 'leave') _leaveClass();
            },
            itemBuilder: (context) {
              if (widget.userRole == 'teacher') {
                return [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Class')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete Class', style: TextStyle(color: Colors.red))),
                ];
              } else {
                return [
                  const PopupMenuItem(value: 'leave', child: Text('Leave Class', style: TextStyle(color: Colors.red))),
                ];
              }
            },
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildStreamTab(),
          _buildClassworkTab(),
          _buildPeopleTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
          // Refresh people tab when selected
          if (index == 2) {
            _fetchMembers();
          }
          if (index == 1) {
            _fetchClasswork();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.stream_outlined),
            selectedIcon: Icon(Icons.stream),
            label: 'Stream',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Classwork',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
        ],
      ),
    );
  }

  // ======================== STREAM TAB ========================

  Widget _buildStreamTab() {
    return RefreshIndicator(
      onRefresh: _fetchAnnouncements,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Banner
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.classData['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.classData['class_code'] != null && widget.userRole == 'teacher')
                  Text(
                    'Class Code: ${widget.classData['class_code']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Share something box (Teacher only)
          if (widget.userRole == 'teacher')
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: _showPostAnnouncementDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Share something with your class...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Announcements
          if (_loadingAnnouncements)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (_announcements.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'This is where you can talk to your class',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ..._announcements.map((a) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            (a['authorName'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['authorName'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _formatDate(a['CreatedAt']),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Delete button only for teachers
                        if (widget.userRole == 'teacher')
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
                            onPressed: () => _deleteItem('announcement', a['Id']),
                            tooltip: 'Delete announcement',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      text: a['PostContent'] ?? '',
                      style: const TextStyle(fontSize: 15),
                      linkStyle: const TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  // ======================== CLASSWORK TAB ========================

  Widget _buildClassworkTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchClasswork,
        child: _loadingClasswork
            ? const Center(child: CircularProgressIndicator())
            : _classworkItems.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No classwork yet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.userRole == 'teacher'
                                  ? 'Tap + to create an assignment or material'
                                  : 'Your teacher hasn\'t posted any classwork yet',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classworkItems.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(_classworkItems[index]);
                      if (item['itemType'] == 'material') {
                        return _buildMaterialCard(item);
                      } else if (item['itemType'] == 'question') {
                        return _buildQuestionCard(item);
                      }
                      return _buildAssignmentCard(item);
                    },
                  ),
      ),
      floatingActionButton: widget.userRole == 'teacher'
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'assignment') _showCreateAssignmentDialog();
                if (value == 'material') _showCreateMaterialDialog();
                if (value == 'question') _showCreateQuestionDialog();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'assignment', child: Text('Assignment')),
                const PopupMenuItem(value: 'question', child: Text('Question')),
                const PopupMenuItem(value: 'material', child: Text('Material')),
              ],
              child: FloatingActionButton.extended(
                onPressed: null,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            )
          : null,
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialDetailScreen(
                materialData: material,
                userRole: widget.userRole,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.book,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['Title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Posted by ${material['uploaderName'] ?? 'Teacher'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (material['FilePath'] != null && material['FilePath'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('File attached', style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.userRole == 'teacher')
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteItem('material', material['Id']),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = DateTime.tryParse(assignment['DueDate'] ?? '');
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    final status = assignment['submissionStatus'] as String?;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (widget.userRole == 'student') {
      switch (status) {
        case 'graded':
          statusColor = Colors.green;
          statusText = 'Graded: ${assignment['submissionGrade']}/100';
          statusIcon = Icons.check_circle;
          break;
        case 'submitted':
          statusColor = Colors.blue;
          statusText = 'Submitted';
          statusIcon = Icons.done;
          break;
        default:
          statusColor = isOverdue ? Colors.red : Colors.orange;
          statusText = isOverdue ? 'Missing' : 'Not submitted';
          statusIcon = isOverdue ? Icons.error : Icons.schedule;
      }
    } else {
      final count = assignment['submissionCount'] ?? 0;
      statusColor = Colors.blue;
      statusText = '$count submissions';
      statusIcon = Icons.people;
    }

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
          // Refresh after returning
          _fetchAssignments();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueDate != null
                          ? 'Due: ${DateFormat('dd MMM yyyy, HH:mm').format(dueDate)}'
                          : 'No due date',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final dueDate = DateTime.tryParse(question['DueDate'] ?? question['dueDate'] ?? '');
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    final status = question['submissionStatus'] as String?;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (widget.userRole == 'student') {
      switch (status) {
        case 'graded':
          statusColor = Colors.green;
          statusText = 'Graded: ${question['submissionGrade']}/100';
          statusIcon = Icons.check_circle;
          break;
        case 'submitted':
          statusColor = Colors.blue;
          statusText = 'Answered';
          statusIcon = Icons.done;
          break;
        default:
          statusColor = isOverdue ? Colors.red : Colors.orange;
          statusText = isOverdue ? 'Missing' : 'Not answered';
          statusIcon = isOverdue ? Icons.error : Icons.schedule;
      }
    } else {
      final count = question['submissionCount'] ?? 0;
      statusColor = Colors.blue;
      statusText = '$count answers';
      statusIcon = Icons.people;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuestionDetailScreen(
                questionData: question,
                userRole: widget.userRole,
              ),
            ),
          );
          _fetchClasswork();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['Title'] ?? question['title'] ?? 'Untitled Question',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueDate != null
                          ? 'Due: ${DateFormat('dd MMM yyyy, HH:mm').format(dueDate)}'
                          : 'No due date',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.userRole == 'teacher')
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteItem('question', question['Id'] ?? question['id']),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ======================== PEOPLE TAB ========================

  Widget _buildPeopleTab() {
    if (_loadingPeople) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchMembers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Teachers Section
          const Text(
            'Teachers',
            style: TextStyle(fontSize: 28, color: Colors.blue, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.blue, thickness: 2),
          if (_teachers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No teacher information available'),
            )
          else
            ..._teachers.map((teacher) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  (teacher['Fullname'] ?? 'T')[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                teacher['Fullname'] ?? 'Unknown Teacher',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(teacher['Email'] ?? ''),
            )),
          const SizedBox(height: 24),
          // Students Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Students',
                style: TextStyle(fontSize: 28, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_students.length} student${_students.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: Colors.blue, thickness: 2),
          if (_students.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32.0),
              child: Center(child: Text('No students have joined yet')),
            )
          else
            ..._students.map((student) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                  (student['Fullname'] ?? 'S')[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                student['Fullname'] ?? 'Unknown Student',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student['Email'] ?? ''),
                  if (widget.userRole == 'teacher') ...[
                    const SizedBox(height: 4),
                    Text('NIS: ${student['NIS'] ?? '-'} | NISN: ${student['NISN'] ?? '-'}'),
                    Text('Major: ${student['MajorName'] ?? '-'}'),
                  ]
                ],
              ),
              trailing: widget.userRole == 'teacher'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditStudentDialog(Map<String, dynamic>.from(student)),
                          tooltip: 'Edit student info',
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeMember(student['Id']),
                          tooltip: 'Remove student',
                        ),
                      ],
                    )
                  : null,
            )),
        ],
      ),
    );
  }

  // ======================== HELPERS ========================

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    final nisController = TextEditingController(text: student['NIS']?.toString() ?? '');
    final nisnController = TextEditingController(text: student['NISN']?.toString() ?? '');
    int? selectedMajorId = student['MajorId'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Student Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nisController,
                  decoration: const InputDecoration(
                    labelText: 'NIS',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nisnController,
                  decoration: const InputDecoration(
                    labelText: 'NISN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Major',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMajorId,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._majors.map((m) => DropdownMenuItem<int>(
                          value: m['Id'],
                          child: Text(m['Name']),
                        ))
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedMajorId = val);
                  },
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
              onPressed: () async {
                Navigator.pop(context);
                await _updateStudentInfo(
                  student['Id'],
                  nisController.text.trim(),
                  nisnController.text.trim(),
                  selectedMajorId,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStudentInfo(int studentId, String nis, String nisn, int? majorId) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/classes/${widget.classData['id']}/members/$studentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nis': nis,
          'nisn': nisn,
          'majorId': majorId,
        }),
      );
      if (response.statusCode == 200) {
        await _fetchMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student info updated'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update student info'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating student info'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
