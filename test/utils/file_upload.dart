import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

Future<String?> uploadImage(String apiUrl, File imageFile) async {
  try {
    // Open a byte stream
    ByteStream stream = ByteStream(imageFile.openRead());
    // Get the length of the file
    int length = await imageFile.length();

    // Create the multipart request, add file and headers
    MultipartRequest request = MultipartRequest('POST', Uri.parse(apiUrl));
    MultipartFile multipartFile = MultipartFile(
      'image',
      stream,
      length,
      contentType: MediaType('image', 'png'),
      filename: imageFile.path.split('/').last,
    );

    request.fields['foo'] = 'bar';

    request.files.add(multipartFile);

    // Optional: If your API requires any headers, you can set them here
    // request.headers['Authorization'] = 'Bearer YOUR_ACCESS_TOKEN';

    // Send the request and wait for the response
    StreamedResponse response = await request.send();

    // Check if the request was successful (status code 200-299)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return await response.stream.transform(utf8.decoder).join();
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}
