import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_system_proxy/flutter_system_proxy.dart';
import 'package:get/get.dart';

import 'log_service.dart';

class NetworkService extends GetxService {
  NetworkService(this.logs);

  final LogService logs;
  late final Dio client;
  final _loggedProxyRoutes = <String>{};

  Future<NetworkService> init() async {
    client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'User-Agent': 'atri-bot-launcher'},
      ),
    );
    client.httpClientAdapter = _SystemProxyHttpClientAdapter(_findProxy);
    logs.info('Dio HTTP 客户端已初始化，已启用系统与环境代理检测');
    return this;
  }

  Future<String> _findProxy(Uri uri) async {
    var proxy = HttpClient.findProxyFromEnvironment(uri);
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        proxy = await FlutterSystemProxy.findProxyFromEnvironment(
          uri.toString(),
        );
      } on MissingPluginException catch (exception) {
        logs.warning('系统代理插件不可用，已回退到环境代理', {'error': '$exception'});
      } on PlatformException catch (exception) {
        logs.warning('读取系统代理失败，已回退到环境代理', {
          'error': exception.message ?? exception.code,
        });
      }
    }
    final route = '${uri.host}|$proxy';
    if (_loggedProxyRoutes.add(route)) {
      logs.info('网络请求代理已解析', {'target': uri.host, 'proxy': proxy});
    }
    return proxy;
  }

  @override
  void onClose() {
    client.close(force: true);
    super.onClose();
  }
}

typedef _ProxyResolver = Future<String> Function(Uri uri);

class _SystemProxyHttpClientAdapter implements HttpClientAdapter {
  _SystemProxyHttpClientAdapter(this._resolveProxy);

  final _ProxyResolver _resolveProxy;
  final Map<String, IOHttpClientAdapter> _adapters = {};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw StateError('Cannot send requests after the adapter is closed.');
    }
    final proxy = await _resolveProxy(options.uri);
    if (_closed) {
      throw StateError('Cannot send requests after the adapter is closed.');
    }
    final adapter = _adapters.putIfAbsent(
      proxy,
      () => IOHttpClientAdapter(
        createHttpClient: () {
          final httpClient = HttpClient()
            ..idleTimeout = const Duration(seconds: 3);
          httpClient.findProxy = (_) => proxy;
          return httpClient;
        },
      ),
    );
    return adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    if (_closed) return;
    _closed = true;
    for (final adapter in _adapters.values) {
      adapter.close(force: force);
    }
    _adapters.clear();
  }
}
