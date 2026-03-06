/// Normalize a title for fuzzy comparison: lowercase, strip punctuation,
/// strip leading articles, trim whitespace.
String normalizeTitle(String s) {
  var n = s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
  n = n.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
  return n;
}
