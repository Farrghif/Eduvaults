import 'package:flutter/material.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ClassDetailScreen({super.key, required this.classData});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show class info
            },
          ),
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

  Widget _buildStreamTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Banner
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.classData['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.classData['section'] != null && widget.classData['section'].toString().isNotEmpty)
                Text(
                  widget.classData['section'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Share something box
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        const SizedBox(height: 24),
        // Empty state for announcements
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
      ],
    );
  }

  Widget _buildClassworkTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No classwork yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Teachers',
          style: TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        const Divider(color: Colors.blue, thickness: 2),
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text('Instructor Name'),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Students',
              style: TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            Text(
              '0 students',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(color: Colors.blue, thickness: 2),
        const Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: Center(child: Text('Invite students to your class')),
        )
      ],
    );
  }
}
