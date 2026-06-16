import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaterialDetailScreen extends StatelessWidget {
  final Map<String, dynamic> materialData;
  final String userRole;

  const MaterialDetailScreen({
    super.key,
    required this.materialData,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(materialData['CreatedAt'] ?? '');
    final hasFile = materialData['FilePath'] != null && materialData['FilePath'].toString().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.book,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materialData['Title'] ?? 'Untitled Material',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Posted by ${materialData['uploaderName'] ?? 'Teacher'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (createdAt != null)
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // File Attachment
            if (hasFile) ...[
              const Text(
                'Attachments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.attach_file, color: Colors.blue),
                  title: Text(
                    materialData['FilePath'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      // Normally we would use url_launcher to open the file URL
                      // final url = '${ApiConfig.baseUrl}/api/uploads/${materialData['FilePath']}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File download feature coming soon!')),
                      );
                    },
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No attachments provided',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
