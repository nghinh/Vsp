import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/text/vietnam_phone.dart';

void main() {
  group('VietnamPhone', () {
    test('reads a number however the golfer writes it', () {
      for (final written in [
        '0947306688',
        '0947 306 688',
        '0947-306-688',
        '+84947306688',
        '+84 947 306 688',
        '84947306688',
        '947306688',
        '  0947306688  ',
      ]) {
        expect(
          VietnamPhone.toE164(written),
          '+84947306688',
          reason: 'failed for "$written"',
        );
      }
    });

    test('keeps 08 numbers whole', () {
      // 084… is a real mobile prefix, so a nine-digit number starting with
      // 84 is a subscriber number, not a country code with a digit missing.
      expect(VietnamPhone.toE164('0842123456'), '+84842123456');
      expect(VietnamPhone.subscriber('842123456'), '842123456');
    });

    test('rejects what cannot receive an SMS', () {
      expect(VietnamPhone.isValid(''), isFalse);
      expect(VietnamPhone.isValid('0947306'), isFalse); // too short
      expect(VietnamPhone.isValid('09473066881'), isFalse); // too long
      expect(VietnamPhone.isValid('02838221234'), isFalse); // landline
      expect(VietnamPhone.isValid('golfer@vsp.local'), isFalse);
    });

    test('passes an email through untouched', () {
      // The sign-in sheet sends both kinds down the same path.
      expect(VietnamPhone.toE164('golfer@vsp.local'), 'golfer@vsp.local');
    });

    test('groups digits for reading', () {
      expect(VietnamPhone.format('0947306688'), '0947 306 688');
      expect(VietnamPhone.format('947306688'), '947 306 688');
      expect(VietnamPhone.format('094'), '094');
      expect(VietnamPhone.format(''), '');
      expect(VietnamPhone.formatE164('0947306688'), '+84 947 306 688');
      expect(VietnamPhone.formatE164('0947'), isNull);
    });
  });

  group('VietnamPhoneInputFormatter', () {
    const formatter = VietnamPhoneInputFormatter();

    TextEditingValue type(String text, {int? caret}) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );

    test('groups as the number is typed', () {
      var value = type('');
      for (final digit in '0947306688'.split('')) {
        final typed = type(
          value.text.substring(0, value.selection.baseOffset) +
              digit +
              value.text.substring(value.selection.baseOffset),
          caret: value.selection.baseOffset + 1,
        );
        value = formatter.formatEditUpdate(value, typed);
      }

      expect(value.text, '0947 306 688');
      expect(value.selection.baseOffset, value.text.length);
    });

    test('keeps the caret where the golfer put it', () {
      // Inserting a 9 at the front of "0947 306 688" — the caret must land
      // after the digit just typed, not at the end of the field.
      final result = formatter.formatEditUpdate(
        type('0947 306 688'),
        type('90947 306 688', caret: 1),
      );

      expect(result.text.replaceAll(' ', ''), '90947306688');
      expect(
        result.text
            .substring(0, result.selection.baseOffset)
            .replaceAll(' ', ''),
        '9',
      );
    });

    test('drops what is not a digit', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        type('09a4b7'),
      );
      expect(result.text, '0947');
    });
  });
}
