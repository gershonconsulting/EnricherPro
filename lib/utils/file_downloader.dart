import 'dart:typed_data';
import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart'
    if (dart.library.io) 'file_downloader_mobile.dart';

/// Platform-agnostic file download interface
abstract class FileDownloader {
  static FileDownloader get instance => getFileDownloader();
  
  void downloadFile(Uint8List bytes, String fileName);
}
