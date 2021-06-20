import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get_ip/get_ip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(SocketState());

class SocketState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: SocketClient(),
    );
  }
}

class SocketClient extends StatefulWidget {

  SocketClientState pageState;

  @override
  SocketClientState createState() {
    pageState = SocketClientState();
    return pageState;
  }
}

class SocketClientState extends State<SocketClient> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String localIP = "";
  int port = 65439;

  // Socket에서 받은 메시지 리스트
  List<MessageItem> items = List<MessageItem>();

  // Socket Server 아이피 입력칸
  TextEditingController ipCon = TextEditingController();
  // Socket Client 메시지 입력칸
  TextEditingController msgCon = TextEditingController();

  Socket clientSocket;

  bool isCamera = false;

  bool isPlaying = false;
  FlutterTts _flutterTts;

  // 사용자 플랫폼 확인
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWeb => kIsWeb;

  // Flutter TTS 모듈 초기화
  initializeTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setSharedInstance(true);  // IOS 용
    _flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers
    ]);   // IOS 용
    _flutterTts.awaitSpeakCompletion(true); // IOS 용

    if (isAndroid) {
      setTtsLanguage();
    } else if (isIOS) {
      setTtsLanguage();
    } else if (isWeb) {
      //not-supported by plugin
    }

    _flutterTts.setStartHandler(() {
      setState(() {
        print("Play!!");
        isPlaying = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete!!");
        isPlaying = false;
      });
    });

    _flutterTts.setErrorHandler((err) {
      setState(() {
        print("error occurred: " + err);
        isPlaying = false;
      });
    });
  }

  //  문자열을 받아와 음성으로 출력
  Future _speak(String text) async {
    if (text != null && text.isNotEmpty) {
      var result = await _flutterTts.speak(text);
      if (result == 1)
        setState(() {
          isPlaying = true;
        });
    }
  }

  //  음성 출력 중단
  Future _stop() async {
    var result = await _flutterTts.stop();
    if (result == 1)
      setState(() {
        isPlaying = false;
      });
  }

  //  전자 언니 언어 세팅
  void setTtsLanguage() async {
    await _flutterTts.setLanguage("en-US");
  }

  // State 초기화
  @override
  void initState() {
    super.initState();
    //  TTS 초기화
    initializeTts();
    //  사용자 아이피 불러옴
    getIP();
    //  불러온 사용자 아이피 State에 띄움
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerIP();
    });
  }

  //  앱을 종료하거나 현재 State 에 나갈때 TTS 중단과 소켓 서버 연결을 끊음
  @override
  void dispose() {
    _flutterTts.stop();
    disconnectFromServer();
    super.dispose();
  }

  //  사용자의 아이피 불러오기
  void getIP() async {
    var ip = await GetIp.ipAddress;
    setState(() {
      localIP = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(title: Text("Socket Client")),
        //  State 화면에 출력될 위젯들을 열로 정렬
        body: Column(
          children: <Widget>[
            ipInfoArea(),
            connectArea(),
            messageListArea(),
            submitArea(),
          ],
        ));
  }

  //  내 아이피 출력
  Widget ipInfoArea() {
    return Card(
      child: ListTile(
        dense: true,
        leading: Text("IP"),
        title: Text(localIP),
      ),
    );
  }

  //  서버의 아이피를 입력 후 소켓 연결을 할 수 있도록 해주는 위젯
  Widget connectArea() {
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Text("Server IP"),
            //  아이피 입력
            title: TextField(
              controller: ipCon,
              decoration: InputDecoration(
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    borderSide: BorderSide(color: Colors.grey[300]),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    borderSide: BorderSide(color: Colors.grey[400]),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50]),
            ),
            trailing: RaisedButton(
              child: Text((clientSocket != null) ? "Disconnect" : "Connect"),
              onPressed:
              (clientSocket != null) ? disconnectFromServer : connectToServer,  //  버튼을 눌렀을 때 클라이언트가 연결돼있으면 연결을 끊고 아니라면 서버 연결
            ),
          ),
          ListTile(
            dense: true,
            leading: Text("Camera Switch"),
            //  아이피 입력
            trailing: RaisedButton(
              child: Text((isCamera == true) ? "On" : "Off"),
              onPressed:
              (isCamera == true) ? onCamera : offCamera,  //  버튼을 눌렀을 때 클라이언트가 연결돼있으면 연결을 끊고 아니라면 서버 연결
            ),
          ),
        ],
      ),
    );
  }

  //  서버로 부터 받은 메시지와 앱을 사용해 보낸 메시지를 출력해주는 위젯
  Widget messageListArea() {
    return Expanded(
      child: ListView.builder(
          reverse: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            //  items(메시지 리스트) 에서 하나씩 가져옴
            MessageItem item = items[index];
            return Container(
              //  만약 메시지의 아이피가 로컬이면 오른쪽 화면에 서버라면 왼쪽화면으로 출력
              alignment: (item.owner == localIP)
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    //  만약 메시지의 아이피가 로컬이면 파란색 박스로 서버라면 회색으로
                    color: (item.owner == localIP)
                        ? Colors.blue[100]
                        : Colors.grey[200]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      //  만약 메시지의 아이피가 로컬이면 클라이언트로 서버라면 서버로
                      (item.owner == localIP) ? "Client" : "Server",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item.content,
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }

  // 메시지 보내는 버튼 위젯
  Widget submitArea() {
    return Card(
      child: ListTile(
        title: TextField(
          //  메시지 박스와 연결하여 메시지 박스에 적힌 데이터를 가져옴
          controller: msgCon,
        ),
        //  Send 버튼
        trailing: IconButton(
          icon: Icon(Icons.send),
          color: Colors.blue,
          disabledColor: Colors.grey,
          //  소켓과 연결되어 있지 않는다면 버튼 비활성화 아니라면 submitMessage 함수 호출
          onPressed: (clientSocket != null) ? submitMessage : null,
        ),
      ),
    );
  }

  //  소켓 연결
  void connectToServer() async {
    print("Destination Address: ${ipCon.text}");
    //  서버 아이피 디스크에 저
    _storeServerIP();

    //  소켓 연결
    Socket.connect(ipCon.text, port, timeout: Duration(seconds: 5))
        .then((socket) {
      setState(() {
        clientSocket = socket;
      });

      //  스낵바 출력하여 소켓 연결 여부와 아이피 출력
      showSnackBarWithKey(
          "Connected to ${socket.remoteAddress.address}:${socket.remotePort}");
      socket.listen(
            (onData) {
          print(String.fromCharCodes(onData).trim());
          //  소켓에서 보내는 데이터를 onData로 받아와 문자열로 변환한 뒤 전자 언니 호출
          _speak(String.fromCharCodes(onData).trim());
          setState(() {
            //  itmes에 메시지 삽입
            items.insert(
                0,
                MessageItem(clientSocket.remoteAddress.address,
                    String.fromCharCodes(onData).trim()));
          });
        },
        onDone: onDone,
        onError: onError,
      );
    }).catchError((e) {
      showSnackBarWithKey(e.toString());
    });
  }

  void onDone() {
    showSnackBarWithKey("Connection has terminated.");
    disconnectFromServer();
  }

  void onError(e) {
    print("onError: $e");
    showSnackBarWithKey(e.toString());
    disconnectFromServer();
  }

  void disconnectFromServer() {
    print("disconnectFromServer");
    //  소켓 연결 끊기
    clientSocket.close();
    setState(() {
      clientSocket = null;
      //  메시지 목록 삭제
      items.clear();
      //  음성 출력 중단
      _stop();
    });
  }

  void offCamera() {
    print("off camera");
    //  소켓 연결 끊기
    setState(() {
      isCamera = false;
      //  메시지 목록 삭제
      sendMessage(0);
      //  음성 출력 중단
    });
  }

  void onCamera() {
    print("on camera");
    //  소켓 연결 끊기
    setState(() {
      isCamera = true;
      //  메시지 목록 삭제
      sendMessage(1);
      //  음성 출력 중단
      _stop();
    });
  }

  void sendMessage(int message) {
    //  소켓 서버에 메시지 전송
    clientSocket.write(message);
  }

  void _storeServerIP() async {
    //  SharedPreferences 모듈을 사용하여 앱이 종료되도 서버 아이피를 저장할 수 있음
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString("serverIP", ipCon.text);
  }

  void _loadServerIP() async {
    //  저장된 아이피를 불러옴
    SharedPreferences sp = await SharedPreferences.getInstance();
    setState(() {
      ipCon.text = sp.getString("serverIP");
    });
  }

  void submitMessage() {
    //  텍스트 필드에 아무것도 없다면 리턴
    if (msgCon.text.isEmpty) return;
    setState(() {
      //  클라이언트가 입력한 메시지 삽입
      items.insert(0, MessageItem(localIP, msgCon.text));
      //  음성 출력
      _speak(msgCon.text);
    });
    //  소켓 전송
    // sendMessage(msgCon.text)
    //  텍스트 필드 비우기
    msgCon.clear();
  }

  //  스낵바 위젯
  showSnackBarWithKey(String message) {
    scaffoldKey.currentState
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Done',
          onPressed: (){},
        ),
      ));
  }
}

//  메시지 저장 클래스
class MessageItem {
  String owner;
  String content;

  MessageItem(this.owner, this.content);
}