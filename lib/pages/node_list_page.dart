import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

class NodeListPage extends StatefulWidget {
  final String ip;
  final String port;

  NodeListPage({required this.ip, required this.port});

  @override
  _NodeListPageState createState() => _NodeListPageState();
}

class _NodeListPageState extends State<NodeListPage> {
  WebSocketChannel? channel;
  StreamSubscription? _subscription;
  StreamSubscription? _nodeInfoSubscription;
  List<String> nodes = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? selectedNodeDetails;

  @override
  void initState() {
    super.initState();
    connectToWebSocket();
  }

  void connectToWebSocket() {
    final uri = 'ws://${widget.ip}:${widget.port}';
    try {
      channel = WebSocketChannel.connect(Uri.parse(uri));
      fetchNodeList();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to connect to WebSocket: $e";
        isLoading = false;
      });
    }
  }

  void fetchNodeList() {
    if (channel == null) {
      setState(() {
        errorMessage = "WebSocket channel is not available.";
        isLoading = false;
      });
      return;
    }

    final request = {
      "op": "call_service",
      "service": "/rosapi/nodes"
    };

    try {
      channel!.sink.add(jsonEncode(request));
      _subscription = channel!.stream.listen((response) {
        final decodedResponse = jsonDecode(response);
        if (mounted) {
          if (decodedResponse["values"] != null &&
              decodedResponse["values"]["nodes"] is List) {
            setState(() {
              nodes = List<String>.from(decodedResponse["values"]["nodes"]);
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
        setState(() {
          errorMessage = "Failed to fetch nodes: $error";
          isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  void fetchNodeDetails(String nodeName) {
    // 기존 채널 대신 새 채널 생성
    final uri = 'ws://${widget.ip}:${widget.port}';
    WebSocketChannel? nodeDetailsChannel;

    try {
      // 새 채널 연결
      nodeDetailsChannel = WebSocketChannel.connect(Uri.parse(uri));

      final request = {
        "op": "call_service",
        "service": "/rosapi/node_details",
        "args": {"node": nodeName}
      };

      // 요청 전송
      nodeDetailsChannel.sink.add(jsonEncode(request));

      // 기존 구독 취소
      _nodeInfoSubscription?.cancel();

      // 새 채널을 통해 응답 수신
      _nodeInfoSubscription = nodeDetailsChannel.stream.listen((response) {
        final decodedResponse = jsonDecode(response);

        if (mounted) {
          if (decodedResponse["values"] != null) {
            setState(() {
              selectedNodeDetails = {
                "subscribing": decodedResponse["values"]["subscribing"],
                "publishing": decodedResponse["values"]["publishing"],
                "services": decodedResponse["values"]["services"]
              };
            });

            // 데이터 수신 후 채널 닫기
            nodeDetailsChannel?.sink.close();
          } else {
            setState(() {
              errorMessage = "Unexpected data format in response.";
            });

            // 데이터가 없으면 채널 닫기
            nodeDetailsChannel?.sink.close();
          }
        }
      }, onError: (error) {
        setState(() {
          errorMessage = "Failed to fetch node details: $error";
        });

        // 에러 발생 시 채널 닫기
        nodeDetailsChannel?.sink.close();
      }, onDone: () {
        // 스트림 종료 시 채널 닫기
        nodeDetailsChannel?.sink.close();
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch node details: $e";
      });

      // 예외 발생 시 채널 닫기
      nodeDetailsChannel?.sink.close();
    }
  }


  Widget buildNodeDetails() {
    if (selectedNodeDetails == null) {
      return Center(child: Text("Select a node to view details."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Subscribing Topics:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(selectedNodeDetails!["subscribing"].length, (index) {
          return Text("- ${selectedNodeDetails!["subscribing"][index]}");
        }),
        SizedBox(height: 16),
        Text("Publishing Topics:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(selectedNodeDetails!["publishing"].length, (index) {
          return Text("- ${selectedNodeDetails!["publishing"][index]}");
        }),
        SizedBox(height: 16),
        Text("Services:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(selectedNodeDetails!["services"].length, (index) {
          return Text("- ${selectedNodeDetails!["services"][index]}");
        }),
      ],
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                return Card(
                  margin: EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(node),
                    onTap: () => fetchNodeDetails(node),
                  ),
                );
              },
            ),
          ),
          Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: buildNodeDetails(),
            ),
          ),
        ],
      ),
    );
  }
}
