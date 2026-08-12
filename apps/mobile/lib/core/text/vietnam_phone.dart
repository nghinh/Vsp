// Vietnamese phone numbers — VSP Mobile App
//
// The server looks an account up by exact string: `findByPhone(identifier)`,
// no normalisation on either side. So the shape the app sends at registration
// and the shape it sends at sign-in have to be the same shape, character for
// character, or the golfer simply cannot get back in.
//
// They were not. The sign-in sheet has always sent "+84" + the number without
// its leading zero, while registration sent whatever was typed into the box —
// "0947306688" for anyone who writes their number the way Vietnamese people
// say it. Register, then try to sign in, and the lookup misses.
//
// This picks the sign-in sheet's shape as the canonical one, because it is
// the one already stored for every account created through that path, and
// puts both screens on the same function.

import 'package:flutter/services.dart';

/// A Vietnamese mobile number, in the one shape the server can match.
abstract final class VietnamPhone {
  /// Mobile prefixes in use after the 2018 renumbering: 03, 05, 07, 08, 09.
  /// A landline (02…) cannot receive the registration SMS, so it is not one
  /// of these on purpose.
  static const String _mobileLeadingDigits = '35789';

  /// The nine digits after the country code, or null if [input] is not a
  /// Vietnamese mobile number.
  ///
  /// Accepts every way a golfer might write it: `0947306688`,
  /// `+84 947 306 688`, `84-947-306-688`, `947306688`.
  static String? subscriber(String input) {
    var digits = input.replaceAll(RegExp('[^0-9]'), '');

    // "84…" is the country code only when what follows is long enough to be
    // a whole number — otherwise it is a subscriber number that happens to
    // start with 84, which 08 prefixes do.
    if (digits.startsWith('84') && digits.length > 9) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 9 || !_mobileLeadingDigits.contains(digits[0])) {
      return null;
    }
    return digits;
  }

  /// True when [input] is a Vietnamese mobile number in any written form.
  static bool isValid(String input) => subscriber(input) != null;

  /// [input] in the exact shape the server stores and matches: `+84947306688`.
  ///
  /// Returns the trimmed input unchanged when it is not a Vietnamese mobile
  /// number, so a caller that also accepts email — the sign-in sheet — can
  /// hand everything through this without mangling the addresses.
  static String toE164(String input) {
    final digits = subscriber(input);
    return digits == null ? input.trim() : '+84$digits';
  }

  /// [input] grouped for reading: `0947 306 688`, or `947 306 688` while the
  /// golfer is still typing and has not written a leading zero.
  static String format(String input) {
    final digits = input.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }

    // A leading zero belongs to the first group, so a whole number reads
    // 4-3-3 the way it is printed on a business card, and a number typed
    // without one reads 3-3-3.
    final head = digits.startsWith('0') ? 4 : 3;
    final groups = <String>[];
    var index = 0;
    for (final size in [head, 3, 3]) {
      if (index >= digits.length) {
        break;
      }
      final end = (index + size).clamp(0, digits.length);
      groups.add(digits.substring(index, end));
      index = end;
    }
    if (index < digits.length) {
      groups.add(digits.substring(index));
    }
    return groups.join(' ');
  }

  /// The canonical number written out for a human: `+84 947 306 688`.
  static String? formatE164(String input) {
    final digits = subscriber(input);
    if (digits == null) {
      return null;
    }
    return '+84 ${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }
}

/// Groups a phone number as it is typed, without losing the caret.
///
/// The spaces are display only — every caller reads the value back through
/// [VietnamPhone.toE164], which throws punctuation away.
class VietnamPhoneInputFormatter extends TextInputFormatter {
  const VietnamPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Count digits rather than characters: inserting a space shifts every
    // character after the caret, so a caret offset measured in characters
    // lands in the wrong place the moment a group closes.
    final digitsBeforeCaret = newValue.text
        .substring(
          0,
          newValue.selection.baseOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp('[^0-9]'), '')
        .length;

    final formatted = VietnamPhone.format(newValue.text);

    var caret = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == digitsBeforeCaret) {
        caret = i;
        break;
      }
      if (formatted[i] != ' ') {
        seen++;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
