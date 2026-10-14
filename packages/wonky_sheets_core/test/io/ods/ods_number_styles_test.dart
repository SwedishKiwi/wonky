import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/io/ods/ods.dart';
import 'package:xml/xml.dart';

const _ns =
    'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
    'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
    'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"';

String? _pattern(String xml) {
  final root = XmlDocument.parse('<r $_ns>$xml</r>').rootElement;
  final styles = {
    for (final e in root.childElements) e.getAttribute('style:name')!: e,
  };
  return OdsNumberStyles.toPattern(
    root.childElements.last,
    (name) => styles[name],
  );
}

void main() {
  group('Given LibreOffice data styles', () {
    const cases = [
      (
        'General',
        '<number:number-style style:name="N0"><number:number number:min-integer-digits="1"/></number:number-style>',
        null,
      ),
      (
        'grouped decimals',
        '<number:number-style style:name="N4"><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1" number:grouping="true"/></number:number-style>',
        '#,##0.00',
      ),
      (
        'optional decimals',
        '<number:number-style style:name="N5"><number:number number:decimal-places="3" number:min-decimal-places="1" number:min-integer-digits="1"/></number:number-style>',
        '0.0##',
      ),
      (
        'percent',
        '<number:percentage-style style:name="N11"><number:number number:decimal-places="0" number:min-decimal-places="0" number:min-integer-digits="1"/><number:text>%</number:text></number:percentage-style>',
        '0%',
      ),
      (
        'euro currency',
        '<number:currency-style style:name="N7"><number:number number:decimal-places="2" number:min-decimal-places="2" number:min-integer-digits="1" number:grouping="true"/><number:text> </number:text><number:currency-symbol number:language="de" number:country="DE">€</number:currency-symbol></number:currency-style>',
        r'#,##0.00 [$€]',
      ),
      (
        'long date',
        '<number:date-style style:name="N37"><number:day-of-week number:style="long"/><number:text>, </number:text><number:month number:textual="true" number:style="long"/><number:text> </number:text><number:day/><number:text>, </number:text><number:year number:style="long"/></number:date-style>',
        'dddd, mmmm d, yyyy',
      ),
      (
        'time with AM/PM',
        '<number:time-style style:name="N41"><number:hours/><number:text>:</number:text><number:minutes number:style="long"/><number:text> </number:text><number:am-pm/></number:time-style>',
        'h:mm AM/PM',
      ),
      (
        'elapsed hours',
        '<number:time-style style:name="N42" number:truncate-on-overflow="false"><number:hours/><number:text>:</number:text><number:minutes number:style="long"/></number:time-style>',
        '[h]:mm',
      ),
      (
        'text',
        '<number:text-style style:name="N100"><number:text-content/></number:text-style>',
        '@',
      ),
      (
        'boolean',
        '<number:boolean-style style:name="N99"><number:boolean/></number:boolean-style>',
        null,
      ),
    ];
    for (final (name, xml, expected) in cases) {
      test('when reading the $name style then the pattern is $expected', () {
        expect(_pattern(xml), expected);
      });
    }
  });

  group('Given Wonky patterns', () {
    const patterns = [
      '#,##0.00',
      '[Red]#,##0;(#,##0)',
      '0.00;-0.00;"zero"',
      'yyyy-mm-dd h:mm',
      '# ?/?',
    ];
    for (final p in patterns) {
      test('when writing "$p" then the Wonky attribute keeps it exactly', () {
        final xml = OdsNumberStyles.toXml(p, 'N1');
        final root = XmlDocument.parse(
          '<r $_ns xmlns:wonky="$kWonkyOdfNamespace">$xml</r>',
        ).rootElement;
        final styles = {
          for (final e in root.childElements) e.getAttribute('style:name')!: e,
        };
        expect(OdsNumberStyles.toPattern(styles['N1']!, (n) => styles[n]), p);
      });
    }
  });
}
