enum ReaderCapability {
  paginated,
  continuous,
  verticalWriting,
  textSelection,
  highlights,
  bookmarks,
  notes,
  search,
  outline,
  statistics,
  media,
  dictionaryLookup,
  recursiveLookup,
  ankiMining,
  audiobookReadAlong,
  customThemes,
  eInk,
  shelves,
  sync,
  backup,
}

class ReaderCapabilitySet {
  final Set<ReaderCapability> values;

  const ReaderCapabilitySet(this.values);

  bool supports(ReaderCapability capability) => values.contains(capability);

  static const core = ReaderCapabilitySet({
    ReaderCapability.paginated,
    ReaderCapability.continuous,
    ReaderCapability.textSelection,
    ReaderCapability.highlights,
    ReaderCapability.bookmarks,
    ReaderCapability.notes,
    ReaderCapability.search,
    ReaderCapability.outline,
    ReaderCapability.statistics,
    ReaderCapability.media,
    ReaderCapability.customThemes,
  });
}
