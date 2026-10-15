/// Chooses which copy of a song to keep.
class DuplicateKeeper {
  static bool preferCandidate({
    required int candidateSize,
    required int existingSize,
    int? candidateBitrate,
    int? existingBitrate,
  }) {
    final candidateRate = candidateBitrate;
    final existingRate = existingBitrate;
    if (candidateRate != null &&
        existingRate != null &&
        candidateRate != existingRate) {
      return candidateRate > existingRate;
    }
    return candidateSize > existingSize;
  }
}
