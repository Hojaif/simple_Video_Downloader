import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

import '../../download_history/components/DownloadItem.dart';

class DownloadService {
  final StreamController<List<DownloadItem>> _streamController =
      StreamController.broadcast();

  Stream<List<DownloadItem>> get downloadStream => _streamController.stream;

  List<DownloadItem> _downloadItems = [];
  int _progress = 0;

  DownloadService() {
    IsolateNameServer.registerPortWithName(
        ReceivePort().sendPort, 'downloader_send_port');
    ReceivePort().listen((dynamic data) {
      final String taskId = data[0];
      final int progress = data[2];

      final item = _downloadItems.firstWhere((item) => item.taskId == taskId,
          orElse: () => DownloadItem(name: taskId, taskId: taskId, url: ""));
      item.progress = progress / 100.0;
      item.isPaused = (data[1] == 3); // Status 3 indicates paused
      _streamController.add(_downloadItems);
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  Future<void> startDownload({
    required String url,
    required String name,
  }) async {
    final externalDir = await getExternalStorageDirectory();

    if (externalDir != null) {
      final filePath = '${externalDir.path}/sample-mp4-file.mp4';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      String taskId = (await FlutterDownloader.enqueue(
        url: url,
        savedDir: externalDir.path,
        showNotification: true,
        openFileFromNotification: true,
      ))!;

      _downloadItems.add(
        DownloadItem(
            name: name,
            progress: _progress.toDouble(),
            taskId: taskId,
            path: filePath,
            url: url),
      );
      _streamController.add(_downloadItems); // Add to stream
    }
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _streamController.close();
  }
}
