/// Note 中独立的音频附件描述。
///
/// 音频文件本身仍存放在 Annotation attachments/ 目录；这里保存播放所需的
/// 稳定元数据，而不是把录音二进制塞进 Note 正文。
class NoteAudio {
  final String id;
  final String path;
  final Duration duration;
  final DateTime createdAt;

  const NoteAudio({
    required this.id,
    required this.path,
    required this.duration,
    required this.createdAt,
  });

  NoteAudio copyWith({
    Duration? duration,
  }) {
    return NoteAudio(
      id: id,
      path: path,
      duration: duration ?? this.duration,
      createdAt: createdAt,
    );
  }
}
