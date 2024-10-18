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
