import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_cafeteria/core/failure.dart';
import 'package:gestor_cafeteria/core/http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

//Crea un ApiClient con un MockClient que siempre responde lo indicado
ApiClient clienteQueResponde(String cuerpo, int codigo) {
  final mock = MockClient(
    (request) async => http.Response(
      cuerpo,
      codigo,
      headers: {'content-type': 'application/json'},
    ),
  );
  return ApiClient(client: mock, baseUrl: 'http://prueba');
}

void main() {
  group('ApiClient', () {
    test('1. GET exitoso (200) devuelve el JSON decodificado', () async {
      final api = clienteQueResponde(
        '[{"id": 1, "customer": "Ana", "drink": "latte", "size": "M"}]',
        200,
      );

      final resultado = await api.get('/orders');

      expect(resultado, isA<List>());
      expect(resultado, [
        {'id': 1, 'customer': 'Ana', 'drink': 'latte', 'size': 'M'},
      ]);
    });

    test('2. Respuesta 404 lanza NotFoundFailure con el mensaje de detail', () {
      final api = clienteQueResponde('{"detail": "Order 9 not found"}', 404);

      expect(
        api.get('/orders/9'),
        throwsA(
          isA<NotFoundFailure>().having(
            (f) => f.message,
            'message',
            'Order 9 not found',
          ),
        ),
      );
    });

    test('3. Respuesta 409 lanza ConflictFailure con el mensaje de detail', () {
      final api = clienteQueResponde(
        '{"detail": "Cannot change status from pending to delivered"}',
        409,
      );

      expect(
        api.patch('/orders/1', {'status': 'delivered'}),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.message,
            'message',
            'Cannot change status from pending to delivered',
          ),
        ),
      );
    });

    test(
      '4. Respuesta 422 lanza ValidationFailure con los campos de detail',
      () {
        final api = clienteQueResponde(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'customer'],
                'msg': 'Must be 1-50 characters',
              },
            ],
          }),
          422,
        );

        expect(
          api.post('/orders', {'customer': '', 'drink': 'latte', 'size': 'M'}),
          throwsA(
            isA<ValidationFailure>().having((f) => f.fields, 'fields', {
              'customer': 'Must be 1-50 characters',
            }),
          ),
        );
      },
    );

    test('5. Respuesta 503 lanza ServerFailure con statusCode 503', () {
      final api = clienteQueResponde('{"detail": "Simulated failure"}', 503);

      expect(
        api.get('/orders'),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('6a. Sin conexion (ClientException) lanza NetworkFailure', () {
      final mock = MockClient((request) async {
        throw http.ClientException('sin red');
      });
      final api = ApiClient(client: mock, baseUrl: 'http://prueba');

      expect(api.get('/orders'), throwsA(isA<NetworkFailure>()));
    });

    test('6b. Tiempo agotado (respuesta mas lenta que el timeout) lanza '
        'NetworkFailure', () {
      final mock = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response('[]', 200);
      });
      final api = ApiClient(
        client: mock,
        baseUrl: 'http://prueba',
        timeout: const Duration(milliseconds: 50),
      );

      expect(api.get('/orders'), throwsA(isA<NetworkFailure>()));
    });

    test('7. Respuesta 300 no es exito y lanza UnexpectedFailure (D3)', () {
      final api = clienteQueResponde('{"detail": "Multiple Choices"}', 300);

      expect(
        api.get('/orders'),
        throwsA(
          isA<UnexpectedFailure>()
              .having((f) => f.statusCode, 'statusCode', 300)
              .having((f) => f.message, 'message', 'Multiple Choices'),
        ),
      );
    });

    test(
      'Codigo no contemplado (418) lanza UnexpectedFailure con su mensaje',
      () {
        final api = clienteQueResponde('{"detail": "Simulated failure"}', 418);

        expect(
          api.get('/orders'),
          throwsA(
            isA<UnexpectedFailure>()
                .having((f) => f.statusCode, 'statusCode', 418)
                .having((f) => f.message, 'message', 'Simulated failure'),
          ),
        );
      },
    );

    test('Error con cuerpo que no es JSON no rompe el cliente', () {
      final api = clienteQueResponde('<html>Bad Gateway</html>', 502);

      expect(
        api.get('/orders'),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 502),
        ),
      );
    });

    test('DELETE exitoso (204 sin cuerpo) termina sin error', () async {
      final api = clienteQueResponde('', 204);

      await expectLater(api.delete('/orders/1'), completes);
    });

    test('Usa el verbo PATCH y envia el cuerpo como JSON', () async {
      late http.Request recibida;
      final mock = MockClient((request) async {
        recibida = request;
        return http.Response('{"id": 1, "status": "preparing"}', 200);
      });
      final api = ApiClient(client: mock, baseUrl: 'http://prueba');

      await api.patch('/orders/1', {'status': 'preparing'});

      expect(recibida.method, 'PATCH');
      expect(recibida.url.toString(), 'http://prueba/orders/1');
      expect(recibida.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(recibida.body), {'status': 'preparing'});
    });
  });
}
