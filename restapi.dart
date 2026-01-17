  // ignore_for_file: non_constant_identifier_names

  import 'dart:convert';
  import 'package:http/http.dart' as http;
  import 'config.dart';

  class DataService {
    // --- FUNGSI UPLOAD ---
    Future<String> upload(List<int> fileBytes, String filename) async {
      String uri = 'https://files.247go.app/files/up';
      try {
        var request = http.MultipartRequest('POST', Uri.parse(uri));
        request.fields['token'] = token;
        request.fields['project'] = project;
        request.files.add(
            http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
        final response = await request.send();
        if (response.statusCode == 200) {
          final res = await http.Response.fromStream(response);
          var body = json.decode(res.body);
          return body['file_name'] ?? '';
        }
        return '';
      } catch (e) {
        return '';
      }
    }

    // --- USERS ---
    Future insertUsers(String appid, String email, String password, String role,
        String profile_data) async {
      String uri = '${baseUrl}insert/';
      try {
        final response = await http.post(Uri.parse(uri), body: {
          'token': token,
          'project': project,
          'collection': 'users',
          'appid': appid,
          'email': email,
          'password': password,
          'role': role,
          'profile_data': profile_data
        });
        return response.statusCode == 200 ? response.body : '[]';
      } catch (e) {
        return '[]';
      }
    }

    // --- LOANS ---
    Future insertLoans(String appid, String user_id, String amount, String tenor,
        String interest_rate, String status, String created_at, String purpose) async {
      String uri = '${baseUrl}insert/';
      try {
        final response = await http.post(Uri.parse(uri), body: {
          'token': token,
          'project': project,
          'collection': 'loans',
          'appid': appid,
          'user_id': user_id,
          'amount': amount,
          'tenor': tenor,
          'interest_rate': interest_rate,
          'status': status,
          'created_at': created_at,
          'purpose': purpose,
        });
        return response.statusCode == 200 ? response.body : '[]';
      } catch (e) {
        return '[]';
      }
    }

    // --- SURVEY (FIXED: 5 PARAMETERS ONLY) ---
    Future insertSurveyresults(String appid, String loan_id, String surveyor_id,
        String photos, String score) async {
      String uri = '${baseUrl}insert/';
      try {
        final response = await http.post(Uri.parse(uri), body: {
          'token': token, 'project': project, 'collection': 'surveyresults',
          'appid': appid,
          'loan_id': loan_id,
          'surveyor_id': surveyor_id,
          'photos': photos,
          'score': score
          // Removed location_lat_long
        });
        return response.statusCode == 200 ? response.body : '[]';
      } catch (e) {
        return '[]';
      }
    }

    // --- TRANSACTIONS ---
    Future insertTransactions(String appid, String loan_id, String user_id,
        String type, String amount, String proof_image, String installment_month,
        String status, String timestamp) async {
      String uri = '${baseUrl}insert/';
      try {
        final response = await http.post(Uri.parse(uri), body: {
          'token': token,
          'project': project,
          'collection': 'transactions',
          'appid': appid,
          'loan_id': loan_id,
          'user_id': user_id,
          'type': type,
          'amount': amount,
          'proof_image': proof_image,
          'installment_month': installment_month,
          'status': status,
          'timestamp': timestamp
        });
        return response.statusCode == 200 ? response.body : '[]';
      } catch (e) {
        return '[]';
      }
    }

    // --- SELECT (GET) ---
    Future selectAll(
        String token, String project, String collection, String appid) async {
      String uri =
          '${baseUrl}select_all/token/$token/project/$project/collection/$collection/appid/$appid';
      try {
        final response = await http.get(Uri.parse(uri));
        return response.statusCode == 200 ? response.body : '[]';
      } catch (e) {
        return '[]';
      }
    }

    Future selectWhere(String token, String project, String collection,
        String appid, String where_field, String where_value) async {
      String uri =
          '${baseUrl}select_where/token/$token/project/$project/collection/$collection/appid/$appid/where_field/$where_field/where_value/$where_value';
      try {
        final response = await http.get(Uri.parse(uri));
        if (response.statusCode == 200) {
          if (response.body.isEmpty || response.body == 'null') return '[]';
          return response.body;
        }
        return '[]';
      } catch (e) {
        return '[]';
      }
    }

    // --- UPDATE & REMOVE ---
    Future updateId(String update_field, String update_value, String token,
        String project, String collection, String appid, String id) async {
      String uri = '${baseUrl}update_id/';
      try {
        final response = await http.post(Uri.parse(uri), body: {
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
          'id': id
        });
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    }

    Future removeId(String token, String project, String collection, String appid,
        String id) async {
      String uri =
          '${baseUrl}remove_id/token/$token/project/$project/collection/$collection/appid/$appid/id/$id';
      try {
        final response = await http.delete(Uri.parse(uri));
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    }
  }
