// ============================================
// lib/utils/file_saver.dart
// ============================================

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_other.dart';

abstract class FileSaver {
  factory FileSaver() => createFileSaver();
  
  /// Sauvegarde le fichier et retourne son chemin ou le statut
  Future<String> saveFile(List<int> bytes, String fileName);
}
