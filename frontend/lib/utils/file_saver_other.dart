// ============================================
// lib/utils/file_saver_other.dart
// ============================================

import 'dart:io';
import 'file_saver.dart';

class OtherFileSaver implements FileSaver {
  @override
  Future<String> saveFile(List<int> bytes, String fileName) async {
    Directory? downloadsDir;

    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          downloadsDir = Directory('$home/Downloads');
        }
      }
    } catch (_) {
      // Ignorer les erreurs d'accès aux variables d'environnement
    }

    // Si on ne trouve pas ou qu'on n'a pas accès, on utilise le dossier temporaire
    if (downloadsDir == null || !await downloadsDir.exists()) {
      downloadsDir = Directory.systemTemp;
    }

    final file = File('${downloadsDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

FileSaver createFileSaver() => OtherFileSaver();
