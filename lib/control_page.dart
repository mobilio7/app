import 'dart:async';
import 'dart:convert'; // JSON encoding을 위한 import
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_joystick/flutter_joystick.dart'; // 조이스틱 라이브러리
import 'dart:typed_data';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';


class ControlScreen extends StatefulWidget {
  final WebSocketChannel channel;
  final String ip;
  final String port;

  ControlScreen({required this.ip, required this.port, required this.channel});

  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool isWebSocketClosed = false; // WebSocket 연결 상태
  double linearVelocity = 0.0; // 조이스틱의 선형 속도 값
  double angularVelocity = 0.0; // 조이스틱의 각속도 값
  double maxLinearSpeed = 1.0; // 최대 선형 속도
  double maxAngularSpeed = 1.0; // 최대 각속도

  String selectedStreamingMode = "WebSocket"; // 기본 모드는 WebSocket
  late VlcPlayerController _vlcController;


  ui.Image? imageData; // imageData 타입 변경
  StreamSubscription? _imageSubscription;
  WebSocketChannel? imageChannel;



  @override
  void initState() {
    super.initState();
    advertiseCmdVel();
    subscribeToImageStream(widget.ip, widget.port);

    _vlcController = VlcPlayerController.network(
      'rtsp://192.168.2.1:8554/test',
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  Uint8List convertRgbToRgba(Uint8List rgbData) {
    final int pixelCount = rgbData.length ~/ 3;
    final Uint8List rgbaData = Uint8List(pixelCount * 4);

    for (int i = 0, j = 0; i < rgbData.length; i += 3, j += 4) {
      rgbaData[j] = rgbData[i];         // R
      rgbaData[j + 1] = rgbData[i + 1]; // G
      rgbaData[j + 2] = rgbData[i + 2]; // B
      rgbaData[j + 3] = 255;            // Alpha (fully opaque)
    }

    return rgbaData;
  }



  Uint8List? decodeImageData(dynamic rawData) {
    if (rawData is String) {
      try {
        return base64Decode(rawData);
      } catch (e) {
        print("Base64 decoding failed: $e");
        return null;
      }
    } else if (rawData is List<dynamic>) {
      try {
        return Uint8List.fromList(rawData.cast<int>());
      } catch (e) {
        print("List<int> conversion failed: $e");
        return null;
      }
    } else {
      print("Unknown data format: $rawData");
      return null;
    }
  }


  void subscribeToImageStream(String ip, String port) {
    final uri = 'ws://$ip:$port';

    try {
      imageChannel = WebSocketChannel.connect(Uri.parse(uri));

      final request = {
        "op": "subscribe",
        "topic": "/camera/color/image_raw",
      };
    imageChannel!.sink.add(jsonEncode(request));

      _imageSubscription?.cancel();

      int frameCounter = 0;
      int frameSkip = 2;

      _imageSubscription = imageChannel!.stream.listen((response) async {
        frameCounter++;
        if (frameCounter % frameSkip != 0) return; // 프레임 건너뛰기
        frameCounter = 0; // 카운터 초기화

        try {
          final decodedResponse = jsonDecode(response);

          if (decodedResponse["msg"] != null) {
            final data = decodedResponse["msg"]["data"];
            final encoding = decodedResponse["msg"]["encoding"];
            final width = decodedResponse["msg"]["width"];
            final height = decodedResponse["msg"]["height"];


            if (encoding != "rgb8") {
              print("Unsupported encoding: $encoding");
              return;
            }

            final Uint8List? bytes = decodeImageData(data);
            if (bytes == null) {
              print("Failed to decode image data.");
              return;
            }

            if (bytes.length != width * height * 3) {
              print("Invalid byte length: ${bytes.length}. Expected: ${width * height * 3}");
              return;
            }

            try {
              final Uint8List rgbaData = convertRgbToRgba(bytes);
              updateImage(rgbaData, width, height); // 상태 업데이트
              print("Converted to RGBA: Length = ${rgbaData.length}");
            } catch (e) {
              print("Error during RGB to RGBA conversion: $e");
              return;
            }
          }
        } catch (e) {
          print("Error processing response: $e");
        }
      }, onError: (error) {
        print("Error subscribing to /image_raw: $error");
      }, onDone: () {
        print("Image stream subscription completed.");
        imageChannel?.sink.close();
      });
    } catch (e) {
      print("Failed to connect to image stream: $e");
    }
  }



  // /cmd_vel 토픽을 광고하는 함수
  void advertiseCmdVel() {
    final advertiseMessage = {
      "op": "advertise",
      "topic": "/cmd_vel",
      "type": "geometry_msgs/Twist"
    };
    widget.channel.sink.add(jsonEncode(advertiseMessage)); // 광고 메시지 전송
    print("Advertised /cmd_vel topic");
  }

  // /cmd_vel 토픽에 명령을 발행하는 함수
  void sendCommand() {
    if (!isWebSocketClosed && widget.channel.closeCode == null) {
      final command = {
        "op": "publish",
        "topic": "/cmd_vel",
        "msg": {
          "linear": {"x": -linearVelocity * maxLinearSpeed, "y": 0.0, "z": 0.0}, // 속도 조절 적용
          "angular": {"x": 0.0, "y": 0.0, "z": -angularVelocity * maxAngularSpeed} // 각속도 조절 적용 (좌우 반전)
        }
      };
      widget.channel.sink.add(jsonEncode(command)); // JSON 직렬화 후 전송
    } else {
      print("WebSocket connection is closed. Cannot send data.");
    }
  }

  void updateImage(Uint8List imageData, int width, int height) {
    ui.decodeImageFromPixels(
      imageData,
      width,
      height,
      ui.PixelFormat.rgba8888,
          (ui.Image image) {
        setState(() {
          this.imageData = image;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        if (_imageSubscription != null) {
          _imageSubscription!.cancel();
          _imageSubscription = null;
        }
        // WebSocket 채널 닫기
        if (imageChannel != null) {
          imageChannel!.sink.close();
          imageChannel = null;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
          appBar: AppBar(
            title: Text('Robot Control'),
            actions: [
              DropdownButton<String>(
                value: selectedStreamingMode,
                items: [
                  DropdownMenuItem(value: "WebSocket", child: Text("WebSocket")),
                  DropdownMenuItem(value: "RTSP", child: Text("RTSP (VLC)")),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedStreamingMode = newValue;
                    });
                  }
                },
                icon: Icon(Icons.video_camera_front), // 아이콘 추가 가능
                underline: Container(), // 밑줄 제거
                style: TextStyle(color: Colors.white), // 텍스트 스타일 조정
                dropdownColor: Colors.blueGrey, // 드롭다운 배경색 조정
              ),
            ],
          ),
        body: Column(
          children: [
            // 상단 60% 화면 영역
            Flexible(
              flex: 6,
              child: Container(
                padding: EdgeInsets.all(16.0),
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selectedStreamingMode == "WebSocket"
                            ? (imageData != null
                            ? RawImage(image: imageData, fit: BoxFit.cover)
                            : Center(child: CircularProgressIndicator()))
                            : VlcPlayer(
                          controller: _vlcController,
                          aspectRatio: 16 / 9,
                          placeholder: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16), // 상단과 하단 간격 추가

            // 하단 조종 부분 - 3줄로 나누기
            Flexible(
              flex: 4, // 40% 영역 차지
              child: Column(
                children: [
                  // 첫 번째 줄 - 맥스 스피드와 조이스틱
                  Expanded(
                    child: Row(
                      children: [
                        // Max Speed 텍스트 부분 박스
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(12.0),
                            margin: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 3,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // 그림자 방향
                                ),
                              ],
                            ),
                            child: Text(
                              'Max Speed:\nLinear: ${maxLinearSpeed.toStringAsFixed(2)} m/s\nAngular: ${maxAngularSpeed.toStringAsFixed(2)} rad/s',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // 조이스틱 영역 박스
                        Container(
                          padding: EdgeInsets.all(10.0),
                          margin: EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 3,
                                blurRadius: 5,
                                offset: Offset(0, 3), // 그림자 방향
                              ),
                            ],
                          ),
                          // 조이스틱 크기 조절
                          width: 90,
                          height: 90,
                          child: Joystick(
                            mode: JoystickMode.all, // 조이스틱 모든 방향 허용
                            listener: (details) {
                              setState(() {
                                linearVelocity = details.y; // 전후 방향
                                angularVelocity = details.x; // 좌우 회전
                              });
                              sendCommand();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 두 번째 줄 - Max Linear Speed 슬라이더
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10.0),
                      margin: EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3), // 그림자 방향
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Max Linear Speed',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Slider(
                            value: maxLinearSpeed,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            label: '${maxLinearSpeed.toStringAsFixed(2)} m/s',
                            onChanged: (value) {
                              setState(() {
                                maxLinearSpeed = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 세 번째 줄 - Max Angular Speed 슬라이더
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10.0),
                      margin: EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3), // 그림자 방향
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Max Angular Speed',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Slider(
                            value: maxAngularSpeed,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            label: '${maxAngularSpeed.toStringAsFixed(2)} rad/s',
                            onChanged: (value) {
                              setState(() {
                                maxAngularSpeed = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 스트림 구독 해제
    if (_imageSubscription != null) {
      _imageSubscription!.cancel();
      _imageSubscription = null;
    }

    // WebSocket 채널 닫기
    if (imageChannel != null) {
      imageChannel!.sink.close();
      imageChannel = null;
    }
    _vlcController.dispose();
    super.dispose();
  }
}
