import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path_provider/path_provider.dart';

class DownloadHistoryScreen extends StatefulWidget {
  final List<DownloadItem> downloads;

  const DownloadHistoryScreen({
    super.key,
    required this.downloads,
  });

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  late StreamController<double> _progressController;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late Stream<ConnectivityResult> _connectivityStream;
  @override
  void initState() {
    super.initState();

    /// .........Check internet connection
    _connectivityStream = _connectivity.onConnectivityChanged;
    _connectivityStream.listen((ConnectivityResult result) {
      setState(() {
        _connectionStatus = result;
      });
      if (_connectionStatus == ConnectivityResult.none) {
        /// .........Lost internet connection
        for (var download in widget.downloads.where((d) => !d.isCompleted)) {
          if (!download.isPaused) {
            _handlePause(download);
            _showSnackbar(context, "ইন্টারনেট কানেকশন চলে গেছে");
          }
        }
      } else {
        /// .........Gained internet connection
        for (var download
            in widget.downloads.where((d) => d.isPaused && !d.isCompleted)) {
          _handleResume(download);
          _showSnackbar(context, "ইন্টারনেট কানেকশন ফিরে এসেছে");
        }
      }
    });
    _updateProgress();
  }

  /// .........Download progress update
  void _updateProgress() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final tasks = await FlutterDownloader.loadTasks();
      if (tasks != null) {
        // For each download, find corresponding task
        for (var download in widget.downloads) {
          try {
            final task = tasks.firstWhere(
              (task) => task.taskId == download.taskId,
              orElse: () => throw Exception('Task not found'),
            );

            setState(() {
              download.progress = task.progress / 100.0;
              download.isPaused = task.status == DownloadTaskStatus.paused;
              download.isCompleted = task.status == DownloadTaskStatus.complete;
              download.isFailed = task.status == DownloadTaskStatus.failed;
            });
          } catch (e) {
            print('Error in finding task for download: ${download.name}');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }

  /// .........Open downloaded file
  void _openDownloadedVideo(BuildContext context, String filePath) async {
    if (filePath.isEmpty) {
      _showSnackbar(context, "File path is invalid.");
      return;
    }

    try {
      await OpenFilex.open(filePath);
    } catch (e) {
      _showSnackbar(context, "Failed to open video: $e");
    }
  }

  /// .........Snacbar
  void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// .........Download pause handle
  Future<void> _handlePause(DownloadItem download) async {
    await FlutterDownloader.pause(taskId: download.taskId);
    setState(() {
      download.isPaused = true;
    });
  }

  /// .........Download resume handle
  Future<void> _handleResume(DownloadItem download) async {
    String? newTaskId = await FlutterDownloader.resume(taskId: download.taskId);
    if (newTaskId != null) {
      setState(() {
        download.taskId = newTaskId;
        download.isPaused = false;
      });
    }
  }

  /// .........Download cancle handle
  void _handleCancel(DownloadItem download) async {
    await FlutterDownloader.remove(
        taskId: download.taskId, shouldDeleteContent: true);
    setState(() {
      widget.downloads.remove(download);
    });
  }

  Future<void> _restartDownload(DownloadItem download) async {
    if (download.isFailed) {
      ///................Download retry
      String? newTaskId =
          await FlutterDownloader.retry(taskId: download.taskId);
      if (newTaskId != null) {
        setState(() {
          download.taskId = newTaskId!;
          download.isPaused = false;
          download.isFailed = false;
          download.progress = 0.0;
        });
        _showSnackbar(context, "Download resumed from where it failed.");
      } else {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final filePath = '${externalDir.path}/${download.name}';
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }

          newTaskId = await FlutterDownloader.enqueue(
            url: download.url, // URL from the 'download' instance
            savedDir: externalDir.path,
            showNotification: true,
            openFileFromNotification: true,
          );

          if (newTaskId != null) {
            setState(() {
              download.taskId = newTaskId!;
              download.isPaused = false;
              download.isFailed = false;
              download.progress = 0.0; // Reset progress
            });
            _showSnackbar(context, "Download restarted from the beginning.");
          } else {
            _showSnackbar(context, "Failed to restart download.");
          }
        } else {
          _showSnackbar(context, "Failed to access storage.");
        }
      }
    } else {
      _showSnackbar(context, "Download has not failed, cannot restart.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download History"),
      ),
      body: ListView(
        children: [
          ///   ............. Downloading UI
          if (widget.downloads.any((item) => !item.isCompleted)) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Downloading...",
                style: TextStyle(fontSize: 20),
              ),
            ),
            ...widget.downloads
                .where((item) => !item.isCompleted)
                .map((download) => DownloadCard(
                      download: download,
                      onPause: () => _handlePause(download),
                      onResume: () => _handleResume(download),
                      onCancel: () {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Are you sure?"),
                                content: Row(
                                  children: [
                                    TextButton(
                                        onPressed: () {
                                          _handleCancel(download);
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          "Yes",
                                          style: TextStyle(color: Colors.green),
                                        )),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          "No",
                                          style: TextStyle(color: Colors.red),
                                        )),
                                  ],
                                ),
                              );
                            });
                      },
                      progress: download.progress,
                      onTap: () {},
                      onRestrad: () {
                        _restartDownload(download);
                      },
                    )),
          ],

          ///   ............. Downloaded UI
          if (widget.downloads.any((item) => item.isCompleted)) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Downloaded",
                style: TextStyle(fontSize: 20),
              ),
            ),
            ...widget.downloads
                .where((item) => item.isCompleted)
                .map((download) => DownloadCard(
                      download: download,
                      onPause: () {},
                      onResume: () {},
                      onCancel: () => _handleCancel(download),
                      progress: download.progress,
                      onTap: () {
                        _openDownloadedVideo(context, download.path ?? "");
                        print("Open path:${download.path}");
                      },
                      onRestrad: () {},
                    )),
          ]
        ],
      ),
    );
  }
}

///....................DownloadCard
class DownloadCard extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onRestrad;
  const DownloadCard({
    super.key,
    required this.download,
    required this.onPause,
    required this.onCancel,
    required this.progress,
    required this.onTap,
    required this.onResume,
    required this.onRestrad,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              InkWell(
                onTap: download.isPaused
                    ? onResume
                    : download.isFailed
                        ? onRestrad
                        : onPause,
                child: CircleAvatar(
                  radius: 20,
                  child: Icon(download.isPaused
                      ? Icons.play_arrow
                      : download.isFailed
                          ? Icons.restart_alt
                          : download.isCompleted
                              ? Icons.check
                              : Icons.pause),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    download.isCompleted
                        ? const Text(
                            "Download Completed",
                            style: TextStyle(
                              color: Colors.green,
                            ),
                          )
                        : Column(
                            children: [
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[300],
                                color: download.isFailed
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    download.isCompleted
                                        ? "Download Completed"
                                        : download.isPaused
                                            ? "Download Paused"
                                            : download.isFailed
                                                ? "Download Failed"
                                                : "Downloading",
                                    style: TextStyle(
                                      color: download.isCompleted
                                          ? Colors.green
                                          : download.isPaused
                                              ? Colors.orange
                                              : download.isFailed
                                                  ? Colors.red
                                                  : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                      "${(progress * 100).toStringAsFixed(0)}%"),
                                ],
                              ),
                            ],
                          )
                  ],
                ),
              ),
              if (!download.isFailed)
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: onCancel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadItem {
  final String name;
  final String url;
  String taskId;
  double progress;
  bool isPaused;
  bool isCompleted;
  bool isFailed;
  String? path;

  DownloadItem({
    required this.name,
    required this.url,
    required this.taskId,
    this.progress = 0.0,
    this.isPaused = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.path,
  });
}
