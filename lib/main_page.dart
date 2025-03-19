import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'control_page.dart';
import 'web_socket_page.dart';
import 'publish_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'monitor_page.dart';
import 'map_page.dart';
import 'rtsp_page.dart';


class MainPage extends StatefulWidget {
  final String ip;
  final String port;
  final WebSocketChannel channel;
  MainPage({required this.ip, required this.port, required this.channel});

  @override
  _MainPage createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  late BannerAd _bannerAd;
  bool _isAdLoaded = false;
  String? ip;
  String? port;
  WebSocketChannel? channel;

  @override
  void initState() {
    ip  = widget.ip;
    port = widget.port;
    channel = widget.channel;
    _loadBannerAd();
    super.initState();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4944591538704535/6642149179',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          print('배너 광고 로드 실패: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async{
        if (didPop) {
          return;
        }
        channel?.sink.close();
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Tools'),
          backgroundColor: Colors.blueGrey,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 연결된 IP와 Port 정보 표시
              Container(
                margin: EdgeInsets.symmetric(vertical: 10),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.router, size: 40, color: Colors.blueGrey),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected to Robot',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text('IP Address: $ip', style: TextStyle(fontSize: 16)),
                            Text('Port: $port', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 버튼 리스트를 2열 그리드로 배치
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildButton(context, 'Control Robot', Icons.settings_remote, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ControlScreen(ip: ip!, port: port!, channel: channel!)),
                      );
                    }),
                    _buildButton(context, 'Ros Lists', Icons.list, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WebSocketPage(ip: ip!, port: port!)),
                      );
                    }),
                    _buildButton(context, 'Sensor Monitor', Icons.monitor, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SensorDashboard()),
                      );
                    }),
                    _buildButton(context, 'Map View', Icons.map_outlined, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapVisualizationPage(ip: ip!, port: port!)),
                      );
                    }),
                    _buildButton(context, 'Message Publish', Icons.publish_outlined, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PublishPage(ip: ip!, port: port!)),
                      );
                    }),
                    _buildButton(context, 'Disconnect', Icons.logout, () {
                      channel?.sink.close();
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ),
              if (_isAdLoaded)
                Container(
                  width: _bannerAd.size.width.toDouble(),
                  height: _bannerAd.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        padding: EdgeInsets.all(16),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.blueGrey),
          SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
        child: Text(
          '$title Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
