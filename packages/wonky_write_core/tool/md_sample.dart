import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  const codec = MarkdownCodec();
  const src = '''# Q3 planning: goals & risks

We'll ship v2.0 (finally!) by **Sept. 30** — see [the plan](https://example.com/plan?a=1&b=2).
Use `snake_case_names` and 2 * 3 = 6; email me at bob@example.com or visit www.example.com.

1. First
2. Second
   - nested *item*
3. Third

- [x] done
- [ ] todo

> Quote with _emphasis_
>
> second line

| Name | Value |
| --- | ---: |
| a\\|b | `x|y` |
''';
  final r = codec.importMarkdown(src);
  print(r.warnings);
  print(codec.exportMarkdown(r.delta));
}
