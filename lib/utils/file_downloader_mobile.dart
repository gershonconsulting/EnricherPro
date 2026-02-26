import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'file_downloader.dart';

class FileDownloaderImpl implements FileDownloader {
  @override
  void downloadFile(Uint8List bytes, String fileName) {
    // On mobile, we would typically use path_provider and share the file
    // For now, just log that download was requested
    if (kDebugMode) {
      debugPrint('File download requested: $fileName (${bytes.length} bytes)');
      debugPrint('On mobile, files are typically saved to Downloads folder or shared via Share dialog');
    }
    
    // In a production app, you would:
    // 1. Use path_provider to get Downloads directory
    // 2. Save file there
    // 3. Show notification or use Share dialog
    throw UnimplementedError('Mobile file download requires additional setup (path_provider, file sharing)');
  }
}

FileDownloader getFileDownloader() => FileDownloaderImpl();
