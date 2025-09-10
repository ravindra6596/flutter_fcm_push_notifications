import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];
    final jsonString = await rootBundle.loadString('assets/server_key_info.json');
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(
        jsonDecode(jsonString),
      ),
      scopes,
    );
    final accessServerToken = client.credentials.accessToken.data;
    return accessServerToken;
  }
}
