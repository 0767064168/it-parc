// ============================================
// lib/utils/file_saver_web.dart
// Implémentation web uniquement (dart:html légitime ici).
// ============================================

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'file_saver.dart';

class WebFileSaver implements FileSaver {
  @override
  Future<String> saveFile(List<int> bytes, String fileName) async {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
    return "Le téléchargement a été lancé dans votre navigateur.";
  }
}

FileSaver createFileSaver() => WebFileSaver();
