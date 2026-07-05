/// Stub for web builds where dart:io is unavailable.
library;

class File {
  File(this.path);
  final String path;
  Future<List<int>> readAsBytes() async => [];
}

class Directory {
  static Directory get systemTemp => Directory('');
  Directory(this.path);
  final String path;
}
