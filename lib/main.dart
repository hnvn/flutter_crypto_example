import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto_keys/crypto_keys.dart';

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _plainTextController = TextEditingController();
  final _buttonActiveController = StreamController<bool>();
  final _encryptedTextController = StreamController<String>();
  final _decryptedTextController = StreamController<String>();

  KeyPair _keyPair;
  EncryptionResult _encryptionResult;

  @override
  void initState() {
    super.initState();

    _loadRSAKey();
  }

  @override
  void dispose() {
    _plainTextController.dispose();
    _buttonActiveController.close();
    _encryptedTextController.close();
    _decryptedTextController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crypto',
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 24.0,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _plainTextController,
                  onChanged: (text) {
                    _checkButtonActive();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Plain text',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 24.0),
                child: StreamBuilder(
                  builder: (_, snapshot) => RaisedButton(
                        color: theme.primaryColor,
                        disabledColor: Colors.grey[400],
                        disabledTextColor: Colors.white,
                        textColor: Colors.white,
                        onPressed: snapshot.data ?? false
                            ? () {
                                _doEncrypt();
                              }
                            : null,
                        child: Text('Encrypt'),
                      ),
                  stream: _buttonActiveController.stream,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: StreamBuilder<String>(
                  builder: (_, snapshot) => snapshot.hasData
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RichText(
                                text: TextSpan(
                                    text: 'Encrypted Text: ',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0),
                                    children: [
                                  TextSpan(
                                      text: snapshot.data,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.normal))
                                ])),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  RaisedButton(
                                    onPressed: _clear,
                                    child: Text('Clear'),
                                    color: Colors.red,
                                    textColor: Colors.white,
                                  ),
                                  SizedBox(
                                    width: 48.0,
                                  ),
                                  RaisedButton(
                                    onPressed: _doDecrypt,
                                    child: Text(
                                      'Decrypt',
                                    ),
                                    color: theme.primaryColor,
                                    textColor: Colors.white,
                                  )
                                ],
                              ),
                            )
                          ],
                        )
                      : Container(),
                  stream: _encryptedTextController.stream,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder(
                  builder: (_, snapshot) => snapshot.hasData
                      ? Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            RichText(
                              text: TextSpan(
                                  text: 'Decrypted Text: ',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.0),
                                  children: [
                                    TextSpan(
                                        text: snapshot.data,
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 16.0))
                                  ]),
                            )
                          ],
                        )
                      : Container(),
                  stream: _decryptedTextController.stream,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _checkButtonActive() {
    _buttonActiveController.sink.add(_plainTextController.text.isNotEmpty);
  }

  _loadRSAKey() async {
    final keyPairJson = await rootBundle.loadString('assets/keypair.json');
    final keyPairMap = json.decode(keyPairJson);
    _keyPair = KeyPair.fromJwk(keyPairMap);
  }

  _doEncrypt() async {
    final text = _plainTextController.text;
    final encryptedText = await _encrypt(text);
    print('Encrypted Text: $encryptedText');
    _encryptedTextController.sink.add(encryptedText);
  }

  _doDecrypt() async {
    final decryptedText = await _decrypt(_encryptionResult);
    print('Decrypted Text: $decryptedText');
    _decryptedTextController.add(decryptedText);
  }

  _clear() {
    _plainTextController.clear();
    _buttonActiveController.add(false);
    _encryptedTextController.add(null);
    _decryptedTextController.add(null);
    _encryptionResult = null;
    setState(() {});
  }

  Future<String> _encrypt(String input) async {
    final encrypter =
        _keyPair.publicKey.createEncrypter(algorithms.encryption.rsa.pkcs1);
    _encryptionResult = encrypter.encrypt(Uint8List.fromList(input.codeUnits));
    return Base64Encoder().convert(_encryptionResult.data);
  }

  Future<String> _decrypt(EncryptionResult input) async {
    final decrypter =
        _keyPair.privateKey.createEncrypter(algorithms.encryption.rsa.pkcs1);
    final output = decrypter.decrypt(input);
    return String.fromCharCodes(output);
  }
}
