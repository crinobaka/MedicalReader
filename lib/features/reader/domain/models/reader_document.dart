enum ReaderDocumentFormat {
  pdf,
  epub,
}

abstract interface class ReaderDocument {
  String get id;
  String get title;
  ReaderDocumentFormat get format;
  ReaderPositionData get initialPositionData;
}

class ReaderPositionData {
  final String? href;
  final int? pageIndex;
  final double progress;

  const ReaderPositionData({
    this.href,
    this.pageIndex,
    this.progress = 0,
  });
}
