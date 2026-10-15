import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps cover images inside the app so the shelf can show them offline.
class ArtworkStore {
  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'artwork'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> saveBytes(String id, Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    final dir = await _dir();
    final file = File(p.join(dir.path, _safe(id)));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> copyFile(String id, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    return saveBytes(id, await source.readAsBytes());
  }

  /// Looks for a cover the folder already carries.
  Future<String?> discoverFolderArt(String folderPath) async {
    const names = [
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'folder.jpg',
      'folder.jpeg',
      'folder.png',
      'album.jpg',
      'album.png',
      'front.jpg',
      'front.png',
    ];
    for (final name in names) {
      final file = File(p.join(folderPath, name));
      if (await file.exists()) return file.path;
    }
    return null;
  }

  String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
