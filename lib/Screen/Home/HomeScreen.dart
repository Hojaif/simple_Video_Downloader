import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mp4downloader/Screen/Home/components/DownloadService.dart';
import 'package:mp4downloader/Screen/Home/components/PermissionService.dart';
import 'package:permission_handler/permission_handler.dart';

import '../download_history/Download_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DownloadService _downloadService = DownloadService();
  final PermissionService _permissionService = PermissionService();

  final String _downloadItem =
      'https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mp4-file.mp4';
  final String _name = "Simple video";

  @override
  void initState() {
    super.initState();
    _permissionService.checkAndRequestNotificationPermission();
  }

  Future<void> _startDownload() async {
    bool hasStoragePermission =
        await _permissionService.checkPermission(Permission.storage);
    if (hasStoragePermission) {
      await _downloadService.startDownload(url: _downloadItem, name: _name);
      _showSnackbar(context, "Download started");
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _startDownload,
              child: const Text("Download Start"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const DownloadHistoryScreen(
                          downloads: [],
                        )));
              },
              child: const Text("View Download History"),
            ),
          ],
        ),
      ),
    );
  }
}
