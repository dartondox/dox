import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

String header(String name) {
  return DownloadableFile(
    ContentType.binary,
    const Stream<List<int>>.empty(),
    name,
  ).contentDisposition;
}

void main() {
  test('a plain ASCII name gives the same header as before', () {
    expect(header('report 2024.pdf'), 'attachment; filename="report 2024.pdf"');
  });

  test('a quote can not add a parameter', () {
    expect(header('a"; x="y.pdf'), r'attachment; filename="a\"; x=\"y.pdf"');
  });

  test('control characters become _', () {
    expect(header('a\r\nb.pdf'), 'attachment; filename="a__b.pdf"');
  });

  test('a non-ASCII name gets an ASCII fallback and filename*', () {
    expect(
      header('résumé.pdf'),
      'attachment; filename="r_sum_.pdf"; '
      "filename*=UTF-8''r%C3%A9sum%C3%A9.pdf",
    );
  });

  test('a non-ASCII name downloads, no 500', () async {
    DoxTestClient client = await DoxTestClient.start(
      AppConfig(appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt'),
    );
    Route.get('/download', (DoxRequest req) {
      return DownloadableFile(
        ContentType.binary,
        Stream<List<int>>.value(<int>[1, 2]),
        'résumé.pdf',
      );
    });
    (await client.get('/download'))
        .expectStatus(200)
        .expectHeader('content-disposition', header('résumé.pdf'));
    await client.close();
  });

  test('withHeaders keeps the headers set before it', () {
    DoxResponse res = DoxResponse(
      DownloadableFile(
        ContentType.binary,
        const Stream<List<int>>.empty(),
        'a.pdf',
      ),
    ).header('X-Old', '1').header('X-Both', 'old');
    res.withHeaders(<String, dynamic>{'X-Both': 'new', 'X-New': '2'});
    expect(res.headers, <String, dynamic>{
      'Content-Disposition': header('a.pdf'),
      'X-Old': '1',
      'X-Both': 'new',
      'X-New': '2',
    });
  });

  test('withHeaders replaces a header in any case', () {
    DoxResponse download = DoxResponse(
      DownloadableFile(
        ContentType.binary,
        const Stream<List<int>>.empty(),
        'a.pdf',
      ),
    ).withHeaders(<String, dynamic>{'content-disposition': 'inline'});
    expect(download.headers, <String, dynamic>{
      'content-disposition': 'inline',
    });

    DoxResponse cached = DoxResponse('x')
        .cache(Duration(seconds: 10))
        .withHeaders(<String, dynamic>{'Cache-Control': 'no-store'});
    expect(cached.headers, <String, dynamic>{'Cache-Control': 'no-store'});
  });

  test('header replaces a header in any case', () {
    DoxResponse cached = DoxResponse('x')
        .cache(Duration(seconds: 10))
        .header('Cache-Control', 'no-store');
    expect(cached.headers, <String, dynamic>{'Cache-Control': 'no-store'});

    DoxResponse res = DoxResponse('x').header('X-A', '1').header('X-A', '2');
    expect(res.headers, <String, dynamic>{'X-A': '2'});
  });
}
