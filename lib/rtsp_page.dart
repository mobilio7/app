import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class RtspStreamScreen extends StatefulWidget {
  @override
  _RtspStreamScreenState createState() => _RtspStreamScreenState();
}

class _RtspStreamScreenState extends State<RtspStreamScreen> {
  late VlcPlayerController _vlcController;

  @override
  void initState() {
    super.initState();
    _vlcController = VlcPlayerController.network(
      'rtsp://192.168.2.1:8554/test',
      hwAcc: HwAcc.full, // 하드웨어 가속 설정
      autoPlay: true, // 자동 재생
      options: VlcPlayerOptions(), // VLC 기본 옵션
    );
  }

  @override
  void dispose() {
    _vlcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RTSP Stream')),
      body: Center(
        child: VlcPlayer(
          controller: _vlcController,
          aspectRatio: 16 / 9,
          placeholder: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
