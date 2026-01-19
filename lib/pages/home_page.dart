import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auto_bookmark_page.dart';
import 'tools_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    // For Android 11+
    if (await Permission.manageExternalStorage.request().isGranted) {
      return;
    }
    // Fallback for older Android
    if (await Permission.storage.request().isGranted) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Tool Pro"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.auto_stories,
            title: "Auto Bookmarks",
            subtitle: "Generate outline from text rules",
            color: Colors.blueAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoBookmarkPage())),
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.bookmark_add,
            title: "Manual Tools",
            subtitle: "Add/Extract bookmarks & Inspect",
            color: Colors.orangeAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
