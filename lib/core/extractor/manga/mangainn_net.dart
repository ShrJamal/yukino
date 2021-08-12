import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import './model.dart';
import '../../../plugins/helpers/querystring.dart';
import '../../../plugins/helpers/utils/http.dart';
import '../../models/languages.dart';

const LanguageCodes _defaultLocale = LanguageCodes.en;

class MangaInnNet extends MangaExtractor {
  @override
  final String name = 'MangaInn.net';

  @override
  final LanguageCodes defaultLocale = _defaultLocale;

  @override
  final String baseURL = 'https://mangainn.net';

  late final Map<String, String> defaultHeaders = <String, String>{
    'User-Agent': HttpUtils.userAgent,
    'Referer': baseURL,
  };

  String searchURL() => '$baseURL/service/advanced_search';

  @override
  Future<List<SearchInfo>> search(
    final String terms, {
    required final LanguageCodes locale,
  }) async {
    try {
      final http.Response res = await http.post(
        Uri.parse(HttpUtils.tryEncodeURL(searchURL())),
        body: QueryString.stringify(<String, dynamic>{
          'type': 'all',
          'status': 'both',
          'manga-name': terms,
        }),
        headers: <String, String>{
          ...defaultHeaders,
          'Content-Type': HttpUtils.contentTypeURLEncoded,
          'x-requested-with': 'XMLHttpRequest',
        },
      ).timeout(HttpUtils.timeout);

      final dom.Document document = html.parse(res.body);
      return document
          .querySelectorAll('.row')
          .map((final dom.Element x) {
            final dom.Element? link = x.querySelector('.manga-title a');
            final String? title = link?.text.trim();
            final String? url = link?.attributes['href']?.trim();
            final String? image =
                x.querySelector('.img-responsive')?.attributes['src']?.trim();

            if (title != null && url != null) {
              return SearchInfo(
                title: title,
                url: url,
                thumbnail: image != null
                    ? ImageInfo(
                        url: image,
                        headers: defaultHeaders,
                      )
                    : null,
                locale: locale,
              );
            }
          })
          .whereType<SearchInfo>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<MangaInfo> getInfo(
    final String url, {
    final LanguageCodes locale = _defaultLocale,
  }) async {
    try {
      final http.Response res = await http
          .get(
            Uri.parse(HttpUtils.tryEncodeURL(url)),
            headers: defaultHeaders,
          )
          .timeout(HttpUtils.timeout);

      final dom.Document document = html.parse(res.body);

      final List<ChapterInfo> chapters = document
          .querySelectorAll('.chapter-list li a')
          .map((final dom.Element x) {
            final String? title = x.querySelector('.val')?.text.trim();
            final String? url = x.attributes['href']?.trim();

            if (title != null && url != null) {
              final List<String> splitTitle = title.split('-');
              final String? shortTitle =
                  splitTitle.length == 2 ? splitTitle[0].trim() : null;
              final String? chap =
                  splitTitle.length == 2 ? splitTitle[1].trim() : null;

              if (chap != null) {
                return ChapterInfo(
                  title: shortTitle ?? title,
                  url: url,
                  chapter: chap,
                  locale: locale,
                );
              }
            }
          })
          .whereType<ChapterInfo>()
          .toList();

      final String? thumbnail =
          document.querySelector('.content img')?.attributes['src']?.trim();
      return MangaInfo(
        title:
            document.querySelector('.content .widget-heading')?.text.trim() ??
                '',
        url: url,
        thumbnail: thumbnail != null
            ? ImageInfo(
                url: thumbnail,
                headers: defaultHeaders,
              )
            : null,
        chapters: chapters,
        locale: locale,
        availableLocales: <LanguageCodes>[
          defaultLocale,
        ],
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PageInfo>> getChapter(final ChapterInfo chapter) async {
    try {
      final http.Response res = await http
          .get(
            Uri.parse(
              HttpUtils.tryEncodeURL(chapter.url),
            ),
            headers: defaultHeaders,
          )
          .timeout(HttpUtils.timeout);

      final dom.Document document = html.parse(res.body);
      return document
              .querySelector('.selectPage select')
              ?.querySelectorAll('option')
              .map(
                (final dom.Element x) {
                  final String? url = x.attributes['value']?.trim();
                  if (url != null) {
                    return PageInfo(
                      url: url,
                      locale: chapter.locale,
                    );
                  }
                },
              )
              .whereType<PageInfo>()
              .toList() ??
          <PageInfo>[];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ImageInfo> getPage(final PageInfo page) async {
    try {
      final http.Response res = await http
          .get(
            Uri.parse(
              HttpUtils.tryEncodeURL(page.url),
            ),
            headers: defaultHeaders,
          )
          .timeout(HttpUtils.timeout);

      final String? image = RegExp('<img src="(.*?)".*class="img-responsive">')
          .firstMatch(res.body)?[1]
          ?.trim();
      if (image is! String) {
        throw AssertionError('Failed to parse image');
      }

      return ImageInfo(
        url: image,
        headers: defaultHeaders,
      );
    } catch (e) {
      rethrow;
    }
  }
}