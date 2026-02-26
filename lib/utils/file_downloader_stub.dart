import 'dart:typed_data';
import 'file_downloader.dart';

class FileDownloaderImpl implements FileDownloader {
  @override
  void downloadFile(Uint8List bytes, String fileName) {
    throw UnsupportedError('File download not supported on this platform');
  }
}

FileDownloader getFileDownloader() => FileDownloaderImpl();
