import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'file_downloader.dart';

class FileDownloaderImpl implements FileDownloader {
  @override
  void downloadFile(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement()
      ..href = url
      ..download = fileName
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

FileDownloader getFileDownloader() => FileDownloaderImpl();
