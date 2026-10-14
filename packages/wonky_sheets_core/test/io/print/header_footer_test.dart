import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/io/print/print.dart';

void main() {
  group('Given a header/footer context', () {
    const ctx = HeaderFooterContext(
      page: 3,
      pages: 12,
      title: 'Budget 2026',
      sheet: 'Q3',
      date: '10/14/2026',
      time: '9:30 AM',
    );
    const cases = [
      ('{page}', '3'),
      ('Page {page} of {pages}', 'Page 3 of 12'),
      ('{title} – {sheet}', 'Budget 2026 – Q3'),
      ('{date} {time}', '10/14/2026 9:30 AM'),
      ('{unknown} {PAGE}', '{unknown} {PAGE}'),
      ('plain text', 'plain text'),
    ];
    for (final (template, expected) in cases) {
      test('when rendering "$template" then it reads "$expected"', () {
        expect(HeaderFooterTokens.render(template, ctx), expected);
      });
    }
  });

  group('Given header/footer flags', () {
    test(
      'when only page numbers are on then the footer gets {page} at the right',
      () {
        const hf = HeaderFooter(footer: HeaderFooterSections());
        expect(hf.effectiveFooter.right, '{page}');
        expect(hf.effectiveHeader.isEmpty, isTrue);
      },
    );

    test(
      'when a custom field already has {page} then it is not added again',
      () {
        const hf = HeaderFooter(
          footer: HeaderFooterSections(center: 'Page {page} of {pages}'),
        );
        expect(hf.effectiveFooter.right, '');
      },
    );

    test(
      'when title, sheet, date and time are on then the header holds them',
      () {
        const hf = HeaderFooter(
          header: HeaderFooterSections(right: 'Printed'),
          flags: HeaderFooterFlags(
            pageNumbers: false,
            title: true,
            sheetName: true,
            date: true,
            time: true,
          ),
        );
        final h = hf.effectiveHeader;
        expect(
          (h.left, h.center, h.right),
          ('{title}', '{sheet}', 'Printed {date} {time}'),
        );
        expect(hf.effectiveFooter.isEmpty, isTrue);
      },
    );
  });

  group('Given a fixed instant', () {
    final now = DateTime.utc(2026, 10, 14, 13, 5);

    test(
      'when formatting in UTC for en_US then date and time are US style',
      () {
        expect(PrintDateTime.format(now), ('10/14/2026', '1:05 PM'));
      },
    );

    test('when formatting in a time zone then the wall clock time is used', () {
      expect(PrintDateTime.format(now, timeZone: 'America/New_York'), (
        '10/14/2026',
        '9:05 AM',
      ));
      expect(PrintDateTime.format(now, timeZone: 'Asia/Tokyo'), (
        '10/14/2026',
        '10:05 PM',
      ));
    });

    test('when formatting for de_DE then German formats are used', () {
      expect(
        PrintDateTime.format(now, locale: 'de_DE', timeZone: 'Europe/Berlin'),
        ('14.10.2026', '15:05'),
      );
    });

    test('when the time zone is unknown then UTC is used', () {
      expect(PrintDateTime.format(now, timeZone: 'Mars/Olympus'), (
        '10/14/2026',
        '1:05 PM',
      ));
    });

    test('when an offset function is injected then it is used', () {
      expect(
        PrintDateTime.format(
          now,
          timeZone: 'Custom',
          utcOffset: (_, _) => const Duration(hours: -2),
        ),
        ('10/14/2026', '11:05 AM'),
      );
    });
  });
}
