import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

import 'package:dart_ping/dart_ping.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';

enum NetworkStatus {
  unreachable,
  wifi,
  mobile2G,
  mobile3G,
  mobile4G,
  mobile5G,
  otherMobile
}

enum InternetStatusConnection {
  withoutInternet,
  withInternet,
  unstableInternet,
}

class NetworkTypeReachability {
  static NetworkTypeReachability _instance;
  factory NetworkTypeReachability() {
    DartPingIOS.register();
    _instance ??= NetworkTypeReachability._();
    return _instance;
  }
  NetworkTypeReachability._();

  static const MethodChannel _channel =
      MethodChannel('flutter_plugin_reachability');

  static const EventChannel _eventChannel =
      EventChannel("flutter_plugin_reachability_status");

  Stream<NetworkStatus> _onNetworkStateChanged;

  /// currentNetworkStatus obtain the status network in live
  Stream<NetworkStatus> get onNetworkStateChanged {
    _onNetworkStateChanged ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString())
        .map(_convertFromState);
    return _onNetworkStateChanged;
  }

  /// currentNetworkStatus obtain the status network
  Future<NetworkStatus> currentNetworkStatus() async {
    final String state = await _channel.invokeMethod("networkStatus");
    return _convertFromState(state);
  }

  /// NetworkStatus identify tipe of connection
  NetworkStatus _convertFromState(String state) {
    switch (state) {
      case "unreach":
        return NetworkStatus.unreachable;
      case "mobile2G":
        return NetworkStatus.mobile2G;
      case "mobile3G":
        return NetworkStatus.mobile3G;
      case "wifi":
        return NetworkStatus.wifi;
      case "mobile4G":
        return NetworkStatus.mobile4G;
      case "mobile5G":
        return NetworkStatus.mobile5G;
      case "mobileOther":
        return NetworkStatus.otherMobile;
      default:
        return NetworkStatus.unreachable;
    }
  }

  /// performs a sending and receiving of packets to an internet page,
  /// if the number of packets sent is equal to the number of packets received
  /// then if there is a good internet connection
  Future<InternetStatusConnection> getInternetStatusConnection({
    urlTest = 'google.com',
    countPing = 3,
    timeOutIntents = 5,
    showLogs = false,
  }) async {
    Ping ping = Ping(urlTest, count: countPing);
    PingData pingData = await ping.stream.last
        .timeout(
      Duration(seconds: timeOutIntents),
    )
        .catchError((e) {
      return null;
    }).onError((error, stackTrace) {
      return null;
    });
    if (showLogs) {
      log('Running PING ===== > $pingData');
    }
    try {
      if (pingData.summary.transmitted == pingData.summary.received) {
        return InternetStatusConnection.withInternet;
      } else if (pingData.summary.transmitted > 0 &&
          pingData.summary.received > 0) {
        return InternetStatusConnection.unstableInternet;
      } else {
        return InternetStatusConnection.withoutInternet;
      }
    } catch (e) {
      return InternetStatusConnection.withoutInternet;
    }
  }

  /// from here on the code focuses on maintaining a listening state wondering if there is an internet connection or not
  bool listenInternet = true;
  bool get listenInternetConnection => listenInternet;
  set listenInternetConnection(data) {
    listenInternet = data;
  }

  Stream<InternetStatusConnection> getStreamInternetConnection(
      {showLogs = false}) async* {
    InternetStatusConnection globalStatusConnection;
    while (listenInternetConnection) {
      try {
        InternetStatusConnection statusConnection =
            await getInternetStatusConnection(showLogs: showLogs);
        if (globalStatusConnection != statusConnection) {
          globalStatusConnection = statusConnection;
          yield globalStatusConnection;
        }
      } catch (error) {
        log(error);
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
