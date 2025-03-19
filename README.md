# ros_tester

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# Flutter ROS Control App

## 프로젝트 개요
이 Flutter 프로젝트는 ROS 기반 로봇을 제어하고 모니터링하기 위한 애플리케이션입니다. 사용자는 WebSocket을 통해 로봇과 연결하고, 제어 및 모니터링 기능을 수행할 수 있습니다.

## 기본적인 빌드 방법
### 1. 환경 설정
- Flutter SDK 설치 (최신 버전 권장)
- `pubspec.yaml` 파일의 의존성을 확인하고 `flutter pub get` 실행

### 2. 실행 방법
```sh
flutter run
```
또는 특정 디바이스에서 실행하려면:
```sh
flutter run -d <device_id>
```

### 3. 빌드
Android APK 빌드:
```sh
flutter build apk
```
iOS 빌드:
```sh
flutter build ios
```

## 프로젝트 구조

### 📂 lib/
- **main.dart** : 앱의 시작점, 전체적인 앱의 엔트리 포인트
- **connect_page.dart** : 로봇의 IP와 Port를 입력받아 WebSocket을 이용해 ROS 시스템에 접속하는 페이지
- **main_page.dart** : 연결된 로봇의 정보를 확인하고 사용할 수 있는 기능을 나열한 페이지
- **control_page.dart** :
  - 조이스틱을 이용해 로봇의 `cmd_vel`을 제어
  - 카메라 스트림을 수신하여 로봇의 실시간 영상 확인 가능
- **map_page.dart** :
  - 2D 맵 데이터를 수신하고 `odom` 토픽을 구독해 로봇의 위치를 표시
  - 터치를 이용해 목표 지점을 설정하고 네비게이션 기능 사용 가능
- **monitor_page.dart** : UI만 구성된 미개발 페이지
- **web_socket_page.dart** : 프로젝트 내 모든 페이지를 `ListView` 형태로 나열하여 확인 가능
- **node_list_page.dart** : 로봇의 ROS 노드 목록을 조회하고 상세 정보를 확인하는 페이지
- **service_list_page.dart** : 서비스 리스트를 확인하는 페이지
- **topic_list_page.dart** : ROS 토픽 리스트와 실시간 발행되는 토픽을 확인하는 페이지
- **publish_page.dart** : 특정 토픽을 직접 발행할 수 있는 페이지
- **rtsp_page.dart** : RTSP 스트림을 받아오는 테스트 페이지

## 실행 및 테스트
1. 로봇의 ROS 네트워크가 활성화되어 있는지 확인
2. `connect_page.dart`에서 IP와 Port 입력 후 WebSocket 연결
3. 각 기능을 실행하며 로봇을 제어 및 모니터링

## 참고 사항
- ROS Master와 연결된 상태에서 앱을 실행해야 합니다.
- ROS 환경에서 WebSocket Bridge가 활성화되어 있어야 합니다.



