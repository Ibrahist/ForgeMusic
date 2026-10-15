import 'dart:io';
import 'dart:typed_data';

/// Reads ReplayGain track gain from the plain text stored in common tags.
class ReplayGainReader {
  static final _pattern = RegExp(
    r'replaygain_track_gain[^0-9+\-]{0,32}([+-]?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static Future<double?> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open();
      final head = await handle.read(length < 512 * 1024 ? length : 512 * 1024);
      Uint8List? tail;
      if (length > head.length) {
        final tailStart = length - 128 * 1024;
        await handle.setPosition(tailStart < 0 ? 0 : tailStart);
        tail = await handle.read(128 * 1024);
      }
      return decode(head) ?? (tail == null ? null : decode(tail));
    } catch (_) {
      return null;
    } finally {
      await handle?.close();
    }
  }

  static double? decode(Uint8List bytes) {
    final direct = String.fromCharCodes(bytes);
    final directHit = _pattern.firstMatch(direct);
    if (directHit != null) return double.tryParse(directHit.group(1)!);
    for (final offset in [0, 1]) {
      final text = _utf16le(bytes, offset);
      final hit = _pattern.firstMatch(text);
      if (hit != null) return double.tryParse(hit.group(1)!);
    }
    return null;
  }

  static String _utf16le(Uint8List bytes, int offset) {
    final codes = <int>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      if (code == 0) continue;
      codes.add(code);
    }
    return String.fromCharCodes(codes);
  }
}
