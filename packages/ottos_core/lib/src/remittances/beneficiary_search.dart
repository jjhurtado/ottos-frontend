final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');

/// Whether [text] can be sent as the beneficiary search (REQ-018): from 2
/// letters (a name) or 4 digits (the end of a phone). Shorter text is not sent.
bool isBeneficiarySearchable(String text) {
  final trimmed = text.trim();
  return _letter.allMatches(trimmed).length >= 2 || _digit.allMatches(trimmed).length >= 4;
}
