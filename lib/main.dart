import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:mp4downloader/Download_history.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _AppState();
}

class _AppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Awesome Notifications - Simple Example',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

// HomeScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ReceivePort _receivePort = ReceivePort();
  final StreamController<List<DownloadItem>> _streamController =
      StreamController.broadcast();
  List<DownloadItem> _downloadItems = [];
  bool isPaused = false;
  int _progress = 0;

  final String _downloadItem =
      'https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mp4-file.mp4';

  final String _name = "Simlple video ";

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, 'downloader_send_port');
    _receivePort.listen((dynamic data) {
      final String taskId = data[0];
      final int progress = data[2];

      setState(() {
        final item = _downloadItems.firstWhere((item) => item.taskId == taskId,
            orElse: () => DownloadItem(name: taskId, taskId: taskId, url: ""));
        item.progress = progress / 100.0;
        item.isPaused = (data[1] == 3); // Status 3 indicates paused
        _streamController.add(_downloadItems);
      });
    });
    FlutterDownloader.registerCallback(downloadCallback);
    _checkAndRequestNotificationPermission();
  }

  Future<void> requestVideoPermission() async {
    PermissionStatus status = await Permission.videos.request();

    if (status.isGranted) {
      // Permission granted
    } else if (status.isDenied) {
      await Permission.videos.request();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  /// Check Notification Permission
  Future<void> _checkAndRequestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.status;

    if (status.isDenied || status.isRestricted) {
      // Request notification permission
      status = await Permission.notification.request();
    }
  }

  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);

    if (status == 4) {
      final SendPort? send =
          IsolateNameServer.lookupPortByName('downloader_send_port');
      send?.send([id, status, progress, true]);
    }
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _streamController.close(); // Close the stream when disposing
    super.dispose();
  }

  /// Check Storage Permission

  Future<bool> _checkPermission(Permission permission) async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
      if (build.version.sdkInt >= 30) {
        var result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      } else {
        var result = await permission.request();
        return result.isGranted;
      }
    } else {
      var result = await permission.request();
      return result.isGranted;
    }
  }

  /// Download Facntion

  Future<void> _startDownload(
      {required String url, required String name}) async {
    bool status = await _checkPermission(Permission.storage);
    if (status) {
      final externalDir = await getExternalStorageDirectory();

      if (externalDir != null) {
        final filePath = '${externalDir.path}/sample-mp4-file.mp4';
        final file = File(filePath);
        print(filePath);
        if (await file.exists()) {
          await file.delete();
        }

        String taskId = (await FlutterDownloader.enqueue(
          url: url,
          savedDir: externalDir.path,
          showNotification: true,
          openFileFromNotification: true,
        ))!;
        setState(() {
          _downloadItems.add(
            DownloadItem(
                name: name,
                progress: _progress.toDouble(),
                taskId: taskId,
                path: filePath,
                url: url),
          );
          _streamController.add(_downloadItems); // Add to stream
        });

        _showSnackbar(context, "Download started");
      }
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                _startDownload(name: _name, url: _downloadItem);
              },
              child: Text("Download Start"),
            ),

            const SizedBox(height: 20),

            /// .........Naviget download view Screen
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DownloadHistoryScreen(
                          downloads: _downloadItems,
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
