import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/list_view_widget.dart';

class ServiceListPage extends StatefulWidget {
  final String ip;
  final String port;

  ServiceListPage({required this.ip, required this.port});

  @override
  _ServiceListPageState createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  WebSocketChannel? channel;
  StreamSubscription? _subscription;
  List<String> services = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    connectToWebSocket();
  }

  void connectToWebSocket() {
    final uri = 'ws://${widget.ip}:${widget.port}';
    try {
      channel = WebSocketChannel.connect(Uri.parse(uri));
      fetchServiceList();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to connect to WebSocket: $e";
        isLoading = false;
      });
    }
  }

  void fetchServiceList() {
    if (channel == null) {
      setState(() {
        errorMessage = "WebSocket channel is not available.";
        isLoading = false;
      });
      return;
    }

    final request = {
      "op": "call_service",
      "service": "/rosapi/services"
    };

    try {
      channel!.sink.add(jsonEncode(request));
      _subscription = channel!.stream.listen((response) {
        final decodedResponse = jsonDecode(response);
        if (mounted) {
          if (decodedResponse["values"] != null &&
              decodedResponse["values"]["services"] is List) {
            setState(() {
              services = List<String>.from(decodedResponse["values"]["services"]);
              isLoading = false;
            });
          } else {
            setState(() {
              errorMessage = "Unexpected data format in response.";
              isLoading = false;
            });
          }
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            errorMessage = "Failed to fetch services: $error";
            isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Error: $e";
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildListView(
      title: 'Service List',
      items: services,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }
}
