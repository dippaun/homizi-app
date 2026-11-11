/// Detects phone numbers, email addresses, and direct-message links in chat.
///
/// The same rules are enforced in Postgres by `public.contains_contact_text`
/// (`supabase/migrations/20261111130000_chat_contact_guard.sql`).
/// A full write-up of what is blocked and what is left alone is in
/// `docs/CHAT_CONTACT.md`.
library;

final _email = RegExp(r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}');

/// `[at]` / `(at)` plus a dotted domain. Ordinary "at the gate" does not match.
final _bracketEmail = RegExp(
  r'''[a-z0-9._%+\-]{1,40}\s*(?:\[at\]|\(at\))\s*[a-z0-9\-]+(?:\s*\.\s*|\s*\[dot\]\s*|\s*\(dot\)\s*|\s+dot\s+)[a-z]{2,}''',
);

final _mailHost = RegExp(
  r'\b(?:gmail|yahoo|outlook|hotmail|rediffmail|protonmail|icloud|googlemail|ymail)\b',
);

final _dotWord = RegExp(r'(?:\[dot\]|\(dot\)|\bdot\b)');

/// `wa.me` must not match the final "t" of a word such as "apartment.me".
final _contactLink = RegExp(
  r'(?:^|[^a-z0-9])(?:wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|whatsapp\.com|t\.me|telegram\.me|telegram\.dog)(?:[^a-z0-9]|$)',
);

const _digitWords = <String, String>{
  'zero': '0',
  'oh': '0',
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
};

final _numberWord = RegExp(
  r'\b(?:zero|oh|one|two|three|four|five|six|seven|eight|nine)\b',
);

final _tripleWord = RegExp(
  r'\btriple\s+(zero|oh|one|two|three|four|five|six|seven|eight|nine|\d)\b',
);

final _doubleWord = RegExp(
  r'\bdouble\s+(zero|oh|one|two|three|four|five|six|seven|eight|nine|\d)\b',
);

/// True when [body] carries a phone, an email, or a wa.me / WhatsApp / Telegram link.
///
/// Rents (`₹18,000`, `18000`), dates, `2BHK` / `1RK`, floor numbers, and
/// 6-digit pincodes stay false. See `docs/CHAT_CONTACT.md`.
bool messageSharesContact(String body) {
  final lower = body.toLowerCase();
  if (_email.hasMatch(lower)) {
    return true;
  }
  if (_bracketEmail.hasMatch(lower)) {
    return true;
  }
  if (_spokenEmail(lower)) {
    return true;
  }
  if (_contactLink.hasMatch(lower)) {
    return true;
  }
  return _hasPhoneRun(_prepare(lower));
}

bool _spokenEmail(String lower) {
  final talksAboutMail = RegExp(r'\be-?mail\b').hasMatch(lower);
  final namesHost = _mailHost.hasMatch(lower);
  if (!talksAboutMail && !namesHost) {
    return false;
  }
  return RegExp(r'\bat\b').hasMatch(lower) && _dotWord.hasMatch(lower);
}

String _digitOf(String token) {
  final mapped = _digitWords[token];
  if (mapped != null) {
    return mapped;
  }
  return token;
}

String _prepare(String lower) {
  var text = lower;
  text = text.replaceAllMapped(_tripleWord, (match) {
    final digit = _digitOf(match.group(1)!);
    return '$digit$digit$digit';
  });
  text = text.replaceAllMapped(_doubleWord, (match) {
    final digit = _digitOf(match.group(1)!);
    return '$digit$digit';
  });
  text = text.replaceAllMapped(_numberWord, (match) {
    return _digitWords[match.group(0)!]!;
  });
  text = text.replaceAll(RegExp(r'\b\d+\s*-?\s*bhks?\b'), ' ');
  text = text.replaceAll(RegExp(r'\b\d+\s*-?\s*rks?\b'), ' ');
  text = text.replaceAll(RegExp(r'\b(?:floor|fl)\.?\s*\d{1,2}\b'), ' ');
  text = text.replaceAll(RegExp(r'\b\d{1,2}(?:st|nd|rd|th)\s+floor\b'), ' ');
  text = text.replaceAll(
    RegExp(r'\b(?:pin\s*code|pincode|pin|zip)\s*[1-8]\d{5}\b'),
    ' ',
  );
  text = text.replaceAllMapped(
    RegExp(r'(?:₹|rs\.?|inr)\s*(\d[\d,]*)(?:\.\d{1,2})?'),
    (match) {
      final digits = match.group(1)!.replaceAll(',', '');
      if (digits.length >= 10) {
        return match.group(0)!;
      }
      return ' ';
    },
  );
  text = text.replaceAllMapped(RegExp(r'\b\d{1,3}(?:,\d{2,3})+\b'), (match) {
    final digits = match.group(0)!.replaceAll(',', '');
    if (digits.length >= 10 && digits.length <= 15) {
      return digits;
    }
    return ' ';
  });
  text = text.replaceAll(RegExp(r'\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b'), ' ');
  text = text.replaceAll(RegExp(r'\b\d{4}[./-]\d{1,2}[./-]\d{1,2}\b'), ' ');
  text = text.replaceAll(
    RegExp(
      r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?(?:,?\s+\d{2,4})?\b',
    ),
    ' ',
  );
  text = text.replaceAll(
    RegExp(
      r'\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?\b',
    ),
    ' ',
  );
  text = text.replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), ' ');
  text = text.replaceAll(RegExp(r'\b\d{1,2}\s*(?:am|pm)\b'), ' ');
  return text;
}

enum _PhoneGap { block, soft, words }

_PhoneGap _phoneGap(String gap) {
  if (gap.length > 48) {
    return _PhoneGap.block;
  }
  if (RegExp(r'''^[\s.\-+()/]*$''').hasMatch(gap)) {
    if (gap.length > 16) {
      return _PhoneGap.block;
    }
    return _PhoneGap.soft;
  }
  final trimmed = gap.trim();
  if (trimmed.isEmpty) {
    return _PhoneGap.soft;
  }
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > 3) {
    return _PhoneGap.block;
  }
  final word = RegExp(r"^[a-z']{1,12}$");
  if (words.every(word.hasMatch)) {
    return _PhoneGap.words;
  }
  return _PhoneGap.block;
}

bool _plusPrefixed(String text, int digitStart) {
  return RegExp(r'\+\s*$').hasMatch(text.substring(0, digitStart));
}

/// Indian mobile, trunk `0…`, or `91` / `091` / `0091` country code.
bool _phoneShaped(String digits) {
  if (digits.length == 10) {
    final lead = digits.codeUnitAt(0);
    return lead >= 0x36 && lead <= 0x39;
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    return true;
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    return true;
  }
  if (digits.length == 13 && digits.startsWith('091')) {
    return true;
  }
  if (digits.length == 14 && digits.startsWith('0091')) {
    return true;
  }
  return false;
}

bool _hasPhoneRun(String text) {
  final matches = RegExp(r'\d+').allMatches(text).toList();
  for (var i = 0; i < matches.length; i++) {
    final first = matches[i].group(0)!;
    if (first.length >= 10 && first.length <= 15) {
      return true;
    }
    if (first.length > 15) {
      continue;
    }
    final plus = _plusPrefixed(text, matches[i].start);
    final buffer = StringBuffer(first);
    var cursor = matches[i].end;
    var wordy = false;
    var dictated = first.length == 1;
    for (var j = i + 1; j < matches.length; j++) {
      final gap = text.substring(cursor, matches[j].start);
      final kind = _phoneGap(gap);
      if (kind == _PhoneGap.block) {
        break;
      }
      final piece = matches[j].group(0)!;
      if (buffer.length + piece.length > 15) {
        break;
      }
      buffer.write(piece);
      cursor = matches[j].end;
      if (kind == _PhoneGap.words) {
        wordy = true;
      }
      if (piece.length == 1) {
        dictated = true;
      }
      final joined = buffer.toString();
      if (plus && joined.length >= 10) {
        return true;
      }
      if (dictated && joined.length >= 10) {
        return true;
      }
      if ((wordy || kind == _PhoneGap.soft) && _phoneShaped(joined)) {
        return true;
      }
    }
  }
  return false;
}
