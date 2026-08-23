// ignore_for_file: avoid_print

import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    print('Sending request to health endpoint...');
    final response = await dio.get(
      'https://mento-ai-proxy.thulminj.workers.dev/v1/health',
    );
    print('Response status: ${response.statusCode}');
    print('Response data: ${response.data}');
  } catch (e) {
    print('Error: $e');
  }
}
