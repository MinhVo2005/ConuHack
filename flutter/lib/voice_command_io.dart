// voice_command_io.dart
// Platform-specific file operations for mobile (iOS/Android)

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Get the path for a temporary recording file
Future<String> getRecordingPath() async {
  final directory = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${directory.path}/voice_command_$timestamp.m4a';
}

/// Read audio bytes from a file path
Future<Uint8List> readAudioBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('Recording file not found');
  }
  return await file.readAsBytes();
}

/// Delete a temporary file
Future<void> deleteFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

/// Write bytes to a temporary file and return the path
Future<String> writeTempAudioFile(Uint8List bytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
