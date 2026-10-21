import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gestor_cafeteria/core/failure.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client;
  final Uri baseUrl;
  final Duration timeout;
  //Clase Client
  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       baseUrl = Uri.parse(
         baseUrl ??
             (const String.fromEnvironment('API_URL').isNotEmpty
                 ? const String.fromEnvironment('API_URL')
                 : (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000')),
       );
  //POST,GET,PATCH,DELETE
  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Object body) => _send('POST', path, body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);
  Future<void> delete(String path) => _send('DELETE', path);

  //Funcion SEND -> Mandar la peticion al Servicio, esperar una respuesta y adecuarlo para flutter

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    //Request: Va arma la peticion con la inyeccion de los HEADERS
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers['Accept'] = 'application/json';
    //Si es una peticion que tiene que mandar un body
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    //Guardar la respuesta del servicio
    final http.Response response;
    //El response se va a tratar segun el caso con el servicio respondio
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on http.ClientException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure();
    }
    final json = _tryDecode(response);
    final code = response.statusCode;
    //Solo los codigos 2xx son exitosos (un 3xx no es un exito)
    if (code >= 200 && code <= 299) return json;
    //Si no fue exitosa, se traduce el codigo HTTP al Failure correspondiente
    throw _toFailure(code, json);
  }

  //Funcion que traduce el codigo de estado y el cuerpo de error a un Failure
  Failure _toFailure(int code, dynamic json) {
    final detail = _detail(json);
    return switch (code) {
      404 => NotFoundFailure(_message(detail) ?? 'Recurso no encontrado'),
      409 => ConflictFailure(
        _message(detail) ?? 'Conflicto con el estado actual',
      ),
      422 => ValidationFailure(_fields(detail)),
      >= 500 && <= 599 => ServerFailure(code),
      _ => UnexpectedFailure(
        code,
        _message(detail) ?? 'Error inesperado ($code)',
      ),
    };
  }

  //Extrae el campo detail sin romperse si el cuerpo es null o no es un mapa
  dynamic _detail(dynamic json) => json is Map ? json['detail'] : null;

  //detail es texto en 404, 409 y errores simulados
  String? _message(dynamic detail) => detail is String ? detail : null;

  //detail es una lista en 422: cada elemento trae loc (lista) y msg
  Map<String, String> _fields(dynamic detail) {
    final fields = <String, String>{};
    if (detail is! List) return fields;
    for (final item in detail) {
      if (item is! Map) continue;
      final loc = item['loc'];
      final msg = item['msg'];
      if (loc is List && loc.length > 1 && msg != null) {
        fields['${loc[1]}'] = '$msg';
      }
    }
    return fields;
  }

  dynamic _tryDecode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
