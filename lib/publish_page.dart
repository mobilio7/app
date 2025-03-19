import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // JSON 파일 로드
import 'package:path_provider/path_provider.dart'; // 파일 저장 경로
import 'package:web_socket_channel/web_socket_channel.dart';

class PublishPage extends StatefulWidget {
  final String ip;
  final String port;

  PublishPage({required this.ip, required this.port});

  @override
  _PublishPageState createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  late WebSocketChannel channel;
  final TextEditingController _topicController = TextEditingController();
  String? selectedType;
  Map<String, dynamic> messageData = {};
  Map<String, dynamic> messageTypes = {};
  String? statusMessage;

  @override
  void initState() {
    super.initState();
    connectToWebSocket();
    loadMessageTypes();
  }

  void connectToWebSocket() {
    final uri = 'ws://${widget.ip}:${widget.port}';
    try {
      channel = WebSocketChannel.connect(Uri.parse(uri));
    } catch (e) {
      setState(() {
        statusMessage = "Failed to connect to WebSocket: $e";
      });
    }
  }

  Future<void> loadMessageTypes() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/message_types.json');

    if (await file.exists()) {
      final jsonString = await file.readAsString();
      setState(() {
        messageTypes = jsonDecode(jsonString);
      });
    } else {
      final defaultJson = await rootBundle.loadString('assets/message_types.json');
      await file.writeAsString(defaultJson);
      setState(() {
        messageTypes = jsonDecode(defaultJson);
      });
    }
  }

  Future<void> saveMessageTypes() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/message_types.json');
    await file.writeAsString(jsonEncode(messageTypes));
  }

  void advertiseAndPublish() {
    final topic = _topicController.text.trim();

    if (topic.isEmpty || selectedType == null || messageData.isEmpty) {
      setState(() {
        statusMessage = "Please fill in all fields.";
      });
      return;
    }

    final advertiseRequest = {
      "op": "advertise",
      "topic": topic,
      "type": selectedType
    };

    try {
      channel.sink.add(jsonEncode(advertiseRequest));

      final publishRequest = {
        "op": "publish",
        "topic": topic,
        "msg": messageData
      };

      channel.sink.add(jsonEncode(publishRequest));
      setState(() {
        statusMessage = "Message published to $topic.";
      });
    } catch (e) {
      setState(() {
        statusMessage = "Failed to publish message: $e";
      });
    }
  }

  void showAddMessageTypeDialog() {
    final TextEditingController typeController = TextEditingController();
    final TextEditingController fieldsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Message Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  decoration: InputDecoration(labelText: 'Message Type Name'),
                ),
                SizedBox(height: 16),
                Container(
                  child: TextField(
                    controller: fieldsController,
                    maxLines: null, // 여러 줄 입력 가능
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: 'Fields (JSON Format)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // JSON 예제 안내 추가
                Text(
                  'Example JSON Format:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '''{
  "orientation": {
    "x": "double",
    "y": "double",
    "z": "double",
    "w": "double"
  },
  "angular_velocity": {
    "x": "double",
    "y": "double",
    "z": "double"
  }
}''',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final typeName = typeController.text.trim();
                final fieldsJson = fieldsController.text.trim();

                if (typeName.isNotEmpty && fieldsJson.isNotEmpty) {
                  try {
                    final fields = jsonDecode(fieldsJson);
                    setState(() {
                      statusMessage = "Message type '$typeName' added.";
                      messageTypes[typeName] = {"fields": fields};
                    });
                    await saveMessageTypes();
                    Navigator.pop(context);
                  } catch (e) {
                    setState(() {
                      statusMessage = "Invalid JSON format for fields.";
                    });
                  }
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void showManageMessageTypesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Manage Message Types'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: messageTypes.keys.map((type) {
                return ListTile(
                  title: Text(type),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // 메시지 타입 삭제
                      setState(() {
                        messageTypes.remove(type);
                      });
                      await saveMessageTypes();
                      Navigator.pop(context); // 다이얼로그 닫기
                      setState(() {
                        statusMessage = "Message type '$type' deleted.";
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }



  List<Widget> buildMessageFields() {
    if (selectedType == null || !messageTypes.containsKey(selectedType)) {
      return [Text("Select a message type to view fields.")];
    }

    List<Widget> fields = [];

    void generateFields(Map<String, dynamic> typeFields, [String prefix = ""]) {
      typeFields.forEach((key, value) {
        final fieldName = prefix.isEmpty ? key : "$prefix/$key";
        if (value is String) {
          // 단일 필드 처리
          fields.add(TextField(
            decoration: InputDecoration(labelText: fieldName),
            onChanged: (input) {
              setState(() {
                if (value == "double") {
                  messageData[fieldName] = double.tryParse(input) ?? 0.0;
                } else {
                  messageData[fieldName] = input;
                }
              });
            },
          ));
        } else if (value is Map<String, dynamic>) {
          // 중첩 필드 처리
          generateFields(value, fieldName);
        }
      });
    }

    Map<String, dynamic> typeFields = messageTypes[selectedType]["fields"];
    generateFields(typeFields);

    return fields;
  }


  @override
  void dispose() {
    _topicController.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Publish Message'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: showAddMessageTypeDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: showManageMessageTypesDialog, // 메시지 타입 관리 다이얼로그 호출
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _topicController,
                decoration: InputDecoration(labelText: 'Topic Name'),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: messageTypes.keys
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedType = value;
                    messageData = {};
                  });
                },
                decoration: InputDecoration(labelText: "Message Type"),
              ),
              SizedBox(height: 16),
              ...buildMessageFields(),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: advertiseAndPublish,
                child: Text('Publish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              if (statusMessage != null) ...[
                SizedBox(height: 16),
                Text(
                  statusMessage!,
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
