import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

class TopicListPage extends StatefulWidget {
  final String ip;
  final String port;

  TopicListPage({required this.ip, required this.port});

  @override
  _TopicListPageState createState() => _TopicListPageState();
}

class _TopicListPageState extends State<TopicListPage> {
  WebSocketChannel? channel;
  StreamSubscription? _subscription;
  Map<String, WebSocketChannel> topicChannels = {};
  Map<String, StreamSubscription> topicSubscriptions = {};
  Map<String, List<String>> topicData = {};
  List<String> topics = [];
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
      fetchTopicList();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to connect to WebSocket: $e";
        isLoading = false;
      });
    }
  }

  void fetchTopicList() {
    if (channel == null) {
      setState(() {
        errorMessage = "WebSocket channel is not available.";
        isLoading = false;
      });
      return;
    }

    final request = {
      "op": "call_service",
      "service": "/rosapi/topics"
    };

    try {
      channel!.sink.add(jsonEncode(request));
      _subscription = channel!.stream.listen((response) {
        final decodedResponse = jsonDecode(response);
        if (mounted) {
          if (decodedResponse["values"] != null &&
              decodedResponse["values"]["topics"] is List) {
            setState(() {
              topics = List<String>.from(decodedResponse["values"]["topics"]);
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
            errorMessage = "Failed to fetch topics: $error";
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

  void subscribeToTopic(String topic) {
    if (topicChannels.containsKey(topic)) {
      return; // 이미 구독 중인 토픽은 무시
    }

    try {
      final uri = 'ws://${widget.ip}:${widget.port}';
      final newChannel = WebSocketChannel.connect(Uri.parse(uri));

      final request = {
        "op": "subscribe",
        "topic": topic,
      };

      newChannel.sink.add(jsonEncode(request));
      final subscription = newChannel.stream.listen((response) {
        final decodedResponse = jsonDecode(response);
        if (mounted && decodedResponse["msg"] != null) {
          setState(() {
            topicData.putIfAbsent(topic, () => []).add(decodedResponse["msg"].toString());
          });
        }
      });

      setState(() {
        topicChannels[topic] = newChannel;
        topicSubscriptions[topic] = subscription;
        topicData[topic] = [];
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to subscribe to topic: $e";
      });
    }
  }

  void unsubscribeFromTopic(String topic) {
    if (!topicChannels.containsKey(topic)) return;

    topicSubscriptions[topic]?.cancel();
    topicChannels[topic]?.sink.close();

    setState(() {
      topicSubscriptions.remove(topic);
      topicChannels.remove(topic);
      topicData.remove(topic);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    topicSubscriptions.values.forEach((sub) => sub.cancel());
    topicChannels.values.forEach((ch) => ch.sink.close());
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Text(
          errorMessage!,
          style: TextStyle(color: Colors.red, fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final topic = topics[index];
          final isSubscribed = topicChannels.containsKey(topic);
          return Column(
            children: [
              ListTile(
                title: Text(topic),
                leading: Icon(Icons.topic, color: isSubscribed ? Colors.green : Colors.blueGrey),
                trailing: IconButton(
                  icon: Icon(isSubscribed ? Icons.cancel : Icons.play_arrow, color: Colors.blueGrey),
                  onPressed: () {
                    if (isSubscribed) {
                      unsubscribeFromTopic(topic);
                    } else {
                      subscribeToTopic(topic);
                    }
                  },
                ),
              ),
              if (isSubscribed)
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Live Data for $topic",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 150,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: topicData[topic]?.length ?? 0,
                          itemBuilder: (context, dataIndex) {
                            return Text(topicData[topic]![dataIndex]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}


