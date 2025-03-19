import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MapVisualizationPage extends StatefulWidget {
  final String ip;
  final String port;

  const MapVisualizationPage({required this.ip, required this.port, Key? key}) : super(key: key);

  @override
  _MapVisualizationPageState createState() => _MapVisualizationPageState();
}

class _MapVisualizationPageState extends State<MapVisualizationPage> {
  late WebSocketChannel mapChannel;
  late WebSocketChannel odomChannel;
  late WebSocketChannel goalChannel;
  late WebSocketChannel tfChannel;

  List<int> mapData = [];
  int mapWidth = 0;
  int mapHeight = 0;
  double originX = 0.0;
  double originY = 0.0;
  double resolution = 0.05;

  double odomX = 0.0;
  double odomY = 0.0;

  double mapToOdomX = 0.0;
  double mapToOdomY = 0.0;

  double robotX = 0.0;
  double robotY = 0.0;

  Offset? targetPoint; // 목표 지점을 저장하는 변수 (하나만 유지)

  List<Map<String, double>> savedLocations = [];

  @override
  void initState() {
    super.initState();
    mapChannel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:${widget.port}'));
    odomChannel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:${widget.port}'));
    goalChannel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:${widget.port}'));
    tfChannel = WebSocketChannel.connect(Uri.parse('ws://${widget.ip}:${widget.port}')); // ✅ 새로운 tfChannel 추가

    subscribeToMapData();
    subscribeToOdomData(); // ✅ 오돔 구독
    subscribeToTFData();
  }

  void subscribeToTFData() {
    final subscribeMessage = {
      "op": "subscribe",
      "topic": "/tf",
    };
    tfChannel.sink.add(jsonEncode(subscribeMessage)); // ✅ TF 데이터는 tfChannel을 통해 구독

    tfChannel.stream.listen((event) {
      final data = jsonDecode(event);

      if (data["transforms"] != null) {
        for (var transform in data["transforms"]) {
          if (transform["header"]["frame_id"] == "map" && transform["child_frame_id"] == "odom") {
            setState(() {
              mapToOdomX = transform["transform"]["translation"]["x"];
              mapToOdomY = transform["transform"]["translation"]["y"];
            });

            // print("🔵 TF (map → odom) Position Updated: X=$mapToOdomX, Y=$mapToOdomY");
          }
        }
      }
    });
  }




  void subscribeToMapData() {
    final subscribeMessage = {
      "op": "subscribe",
      "topic": "/map",
    };
    mapChannel.sink.add(jsonEncode(subscribeMessage));

    mapChannel.stream.listen((event) {
      final data = jsonDecode(event);

      if (data["msg"] != null) {
        setState(() {
          mapWidth = data["msg"]["info"]["width"];
          mapHeight = data["msg"]["info"]["height"];
          originX = data["msg"]["info"]["origin"]["position"]["x"];
          originY = data["msg"]["info"]["origin"]["position"]["y"];
          resolution = data["msg"]["info"]["resolution"];
          mapData = List<int>.from(data["msg"]["data"]);
        });
      }
    });
  }

  void subscribeToOdomData() {
    final subscribeMessage = {
      "op": "subscribe",
      "topic": "/odom",
    };
    odomChannel.sink.add(jsonEncode(subscribeMessage));

    odomChannel.stream.listen((event) {
      final data = jsonDecode(event);

      if (data["msg"] != null) {
        setState(() {
          odomX = data["msg"]["pose"]["pose"]["position"]["x"];
          odomY = data["msg"]["pose"]["pose"]["position"]["y"];
        });

        // print("🟢 Odometry Position Updated: X=$odomX, Y=$odomY");
      }
    });
  }


  void sendGoalPose(double x, double y) {
    final goalMessage = {
      "op": "publish",
      "topic": "/move_base/goal",
      "msg": {
        "header": {
          "seq": 1,
          "stamp": {
            "secs": DateTime.now().millisecondsSinceEpoch ~/ 1000,
            "nsecs": (DateTime.now().millisecondsSinceEpoch % 1000) * 1000000
          },
          "frame_id": ""
        },
        "goal_id": {
          "stamp": {
            "secs": 0,
            "nsecs": 0
          },
          "id": ""
        },
        "goal": {
          "target_pose": {
            "header": {
              "seq": 1,
              "stamp": {
                "secs": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                "nsecs": (DateTime.now().millisecondsSinceEpoch % 1000) * 1000000
              },
              "frame_id": "map"
            },
            "pose": {
              "position": {
                "x": x,
                "y": y,
                "z": 0.0
              },
              "orientation": {
                "x": 0.0,
                "y": 0.0,
                "z": 0.015443391903043946,  // 기본 회전값 설정
                "w": 0.9998807437122335
              }
            }
          }
        }
      }
    };

    goalChannel.sink.add(jsonEncode(goalMessage));
    print("🚀 목표 위치 발행됨: X=$x, Y=$y");
  }


  void sendGoalFromTap(double screenX, double screenY, Size screenSize) {
    // 화면 좌표 → 맵 좌표 변환
    double gridX = (screenX / screenSize.width) * mapWidth;
    double gridY = (screenY / screenSize.height) * mapHeight;

    // 맵 좌표 → ROS 좌표 변환
    double rosX = originX + (gridX * resolution);
    double rosY = originY + (gridY * resolution) - 0.5;

    setState(() {
      targetPoint = Offset(gridX, gridY); // 이전 목표 지점 제거 후 새로운 지점 설정
    });

    // 목표 위치 발행
    sendGoalPose(rosX, rosY);
  }


  @override
  void dispose() {
    mapChannel.sink.close();
    odomChannel.sink.close();
    goalChannel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("2D Map Visualization")),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/mobilio.png', // 이미지 경로 (assets 폴더 내)
                width: 200,                // 원하는 너비 설정
                height: 100,                // 원하는 높이 설정
                fit: BoxFit.contain,       // 이미지 비율 유지
              ),
            ),
            Flexible(
              child: mapData.isNotEmpty
                  ? GestureDetector(
                onTapDown: (details) {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  Offset localPosition = box.globalToLocal(details.globalPosition);
                  sendGoalFromTap(localPosition.dx, localPosition.dy, box.size);
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: mapWidth / mapHeight,
                    child: CustomPaint(
                      painter: MapPainter(
                        mapData: mapData,
                        width: mapWidth,
                        height: mapHeight,
                        odomX: odomX,
                        odomY: odomY,
                        mapToOdomX: mapToOdomX,
                        mapToOdomY: mapToOdomY,
                        originX: originX,
                        originY: originY,
                        resolution: resolution,
                        targetPoint: targetPoint,
                      ),
                    ),
                  ),
                ),
              )
                  : Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final List<int> mapData;
  final int width;
  final int height;
  final double odomX;
  final double odomY;
  final double mapToOdomX;
  final double mapToOdomY;
  final double originX;
  final double originY;
  final double resolution;
  final Offset? targetPoint; // 목표 지점 추가

  MapPainter({
    required this.mapData,
    required this.width,
    required this.height,
    required this.odomX,
    required this.odomY,
    required this.mapToOdomX,
    required this.mapToOdomY,
    required this.originX,
    required this.originY,
    required this.resolution,
    required this.targetPoint, // 목표 지점 받기
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final cellWidth = size.width / width;
    final cellHeight = size.height / height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final value = mapData[y * width + x];

        paint.color = value == -1
            ? Colors.grey  // Unknown area
            : value == 0
            ? Colors.white  // Free space
            : value == 100
            ? Colors.black  // Occupied space
            : Colors.blue;  // Other values

        canvas.drawRect(
          Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
          paint,
        );
      }
    }

    // 🔴 로봇 위치 표시
    paint.color = Colors.red;

    // ✅ `tf`(`map → odom`) 변환을 적용하여 `odom`을 `map` 좌표로 변환
    final robotX = mapToOdomX + odomX;
    final robotY = mapToOdomY + odomY;

    // ✅ 월드 좌표 → 맵 좌표 변환 (grid 기준 좌표)
    final gridX = (robotX - originX) / resolution;
    final gridY = (robotY - originY) / resolution;

    // ✅ 맵 좌표 → 화면 좌표 변환 (Flutter Canvas 기준 좌표)
    final robotPosX = gridX * cellWidth;
    final robotPosY = gridY * cellHeight;

    // print("🔍 Robot Position (TF + Odom): X=$robotX, Y=$robotY");
    // print("🔍 Grid X: $gridX, Grid Y: $gridY");
    // print("🔍 Screen X: $robotPosX, Y: $robotPosY");

    // 로봇 위치를 빨간 원으로 표시
    canvas.drawCircle(Offset(robotPosX, robotPosY), cellWidth * 2, paint);

    // 🔵 목표 지점 표시 (있을 경우)
    if (targetPoint != null) {
      paint.color = Colors.green;
      final goalPosX = targetPoint!.dx * cellWidth;
      final goalPosY = targetPoint!.dy * cellHeight - (10 * cellHeight);
      canvas.drawCircle(Offset(goalPosX, goalPosY), cellWidth * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}