import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebSocketPage extends StatelessWidget {
  final String ip;
  final String port;

  WebSocketPage({required this.ip, required this.port});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ROS Data Viewer'),
        backgroundColor: Colors.blueGrey,
      ),
      body: PageView(
        children: [
          NodeListPage(ip: ip, port: port),
          TopicListPage(ip: ip, port: port),
          ServiceListPage(ip: ip, port: port),
        ],
      ),
    );
  }
}

abstract class WebSocketPageBase extends StatefulWidget {
  final String ip;
  final String port;

  WebSocketPageBase({required this.ip, required this.port});
}

abstract class WebSocketPageBaseState<T extends WebSocketPageBase> extends State<T> {
  WebSocketChannel? channel;
  StreamSubscription? _subscription;
  List<String> items = [];
  bool isLoading = true;
  String? errorMessage;

  String get service; // 페이지마다 서비스 이름을 설정

  @override
  void initState() {
    super.initState();
    connectToWebSocket();
  }

  void connectToWebSocket() {
    final uri = 'ws://${widget.ip}:${widget.port}';
    try {
      channel = WebSocketChannel.connect(Uri.parse(uri));
      fetchData();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to connect to WebSocket: $e";
        isLoading = false;
      });
    }
  }

  void fetchData() {
    if (channel == null) {
      setState(() {
        errorMessage = "WebSocket channel is not available.";
        isLoading = false;
      });
      return;
    }

    final request = {
      "op": "call_service",
      "service": service,
    };

    try {
      channel!.sink.add(jsonEncode(request));
      _subscription = channel!.stream.listen((response) {
        final decodedResponse = jsonDecode(response);

        if (mounted) {
          final valuesKey = service.split('/').last;
          if (decodedResponse["values"] != null &&
              decodedResponse["values"][valuesKey] is List) {
            setState(() {
              items = List<String>.from(decodedResponse["values"][valuesKey]);
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
            errorMessage = "Failed to fetch data: $error";
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
      title: service.split('/').last,
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }
}

class NodeListPage extends WebSocketPageBase {
  NodeListPage({required String ip, required String port}) : super(ip: ip, port: port);

  @override
  _NodeListPageState createState() => _NodeListPageState();
}

class _NodeListPageState extends WebSocketPageBaseState<NodeListPage> {
  @override
  String get service => "/rosapi/nodes";
}

class TopicListPage extends WebSocketPageBase {
  TopicListPage({required String ip, required String port}) : super(ip: ip, port: port);

  @override
  _TopicListPageState createState() => _TopicListPageState();
}

class _TopicListPageState extends WebSocketPageBaseState<TopicListPage> {
  @override
  String get service => "/rosapi/topics";
}

class ServiceListPage extends WebSocketPageBase {
  ServiceListPage({required String ip, required String port}) : super(ip: ip, port: port);

  @override
  _ServiceListPageState createState() => _ServiceListPageState();
}

class _ServiceListPageState extends WebSocketPageBaseState<ServiceListPage> {
  @override
  String get service => "/rosapi/services";
}

Widget buildListView({
  required String title,
  required List<String> items,
  required bool isLoading,
  String? errorMessage,
}) {
  if (isLoading) {
    return Center(child: CircularProgressIndicator());
  }

  if (errorMessage != null) {
    return Center(
      child: Text(
        errorMessage,
        style: TextStyle(color: Colors.red, fontSize: 18),
      ),
    );
  }

  if (items.isEmpty) {
    return Center(
      child: Text(
        'No $title found.',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      return Card(
        elevation: 5,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(Icons.list, color: Colors.blueGrey),
          title: Text(items[index],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    },
  );
}
