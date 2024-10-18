import 'package:flutter/material.dart';
import 'package:mp4downloader/Screen/download_history/components/DownloadItem.dart';

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
