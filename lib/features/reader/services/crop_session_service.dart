import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/crop_configuration.dart';
import '../models/crop_session.dart';

/// 管理裁剪临时目录。
///
/// 注意：这里不会移动、覆盖或修改原始 PDF。
class CropSessionService {
  const CropSessionService();

  Future<Directory> createSessionDirectory(
    LibraryDocument document, {
    String? sessionId,
  }) async {
    final bookDirectory = File(document.file.path).parent;
    final temporaryDirectory = Directory(
      '${bookDirectory.path}${Platform.pathSeparator}temporary',
    );

    await temporaryDirectory.create(recursive: true);

    final id = sessionId ??
        'crop-session-${DateTime.now().microsecondsSinceEpoch}';

    final sessionDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}$id',
    );

    await sessionDirectory.create(recursive: true);
    return sessionDirectory;
  }

  Future<CropSession> createSession({
    required LibraryDocument document,
    required CropConfiguration configuration,
  }) async {
    final sessionId = configuration.temporarySessionId ??
        'crop-session-${DateTime.now().microsecondsSinceEpoch}';
    final directory = await createSessionDirectory(
      document,
      sessionId: sessionId,
    );

    final nextConfiguration = configuration.copyWith(
      sourceDocumentId: document.id,
      temporarySessionId: sessionId,
    );

    final session = CropSession(
      id: sessionId,
      sourceDocumentId: document.id,
      template: nextConfiguration.template.name,
      regions: nextConfiguration.regions.map((region) => region.toJson()).toList(),
      pageStart: nextConfiguration.pageStart,
      pageEnd: nextConfiguration.pageEnd,
      createdAt: nextConfiguration.createdAt,
      directoryPath: directory.path,
    );

    await _manifestFile(directory).writeAsString(session.encode());
    return session;
  }

  Future<File> writePageImage({
    required CropSession session,
    required int pageIndex,
    required List<int> pngBytes,
  }) async {
    final file = File(
      '${session.directoryPath}${Platform.pathSeparator}'
      'page-${(pageIndex + 1).toString().padLeft(3, '0')}.png',
    );

    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  Future<CropSession?> loadSession(
    LibraryDocument document,
    String sessionId,
  ) async {
    final bookDirectory = File(document.file.path).parent;
    final file = File(
      '${bookDirectory.path}${Platform.pathSeparator}temporary'
      '${Platform.pathSeparator}$sessionId${Platform.pathSeparator}manifest.json',
    );

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      return CropSession.fromJson(_decodeObject(content));
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSession(CropSession session) async {
    final directory = Directory(session.directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> cleanupStaleSessions(
    LibraryDocument document, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final bookDirectory = File(document.file.path).parent;
    final temporaryDirectory = Directory(
      '${bookDirectory.path}${Platform.pathSeparator}temporary',
    );

    if (!await temporaryDirectory.exists()) {
      return;
    }

    final now = DateTime.now();
    await for (final entity in temporaryDirectory.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is! Directory) {
        continue;
      }

      final modified = (await entity.stat()).modified;
      if (now.difference(modified) > maxAge) {
        await entity.delete(recursive: true);
      }
    }
  }

  File _manifestFile(Directory directory) {
    return File(
      '${directory.path}${Platform.pathSeparator}manifest.json',
    );
  }

  Map<String, dynamic> _decodeObject(String content) {
    final decoded = content.isEmpty ? const <String, dynamic>{} :
        Map<String, dynamic>.from(const JsonDecoder().convert(content) as Map);
    return decoded;
  }
}
