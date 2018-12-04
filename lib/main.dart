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

enum EncryptMode { non, rsa, aes }

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _plainTextController = TextEditingController();
  final _buttonActiveController = StreamController<bool>();
  final _encryptedTextController = StreamController<String>();
  final _decryptedTextController = StreamController<String>();

  KeyPair _rsaKeyPair;
  KeyPair _aesKeyPair;
  EncryptionResult _encryptionResult;

  EncryptMode _encryptMode = EncryptMode.non;

  @override
  void initState() {
    super.initState();

    _loadRSAKey();

    _loadAESKey();
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
                  builder: (_, snapshot) => Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RaisedButton(
                            color: theme.primaryColor,
                            disabledColor: Colors.grey[400],
                            disabledTextColor: Colors.white,
                            textColor: Colors.white,
                            onPressed: (snapshot.data ?? false) &&
                                    _encryptMode != EncryptMode.aes
                                ? () {
                                    _encryptMode = EncryptMode.rsa;
                                    _doRSAEncrypt();
                                  }
                                : null,
                            child: Text('Encrypt with RSA'),
                          ),
                          SizedBox(
                            width: 48.0,
                          ),
                          RaisedButton(
                            color: theme.primaryColor,
                            disabledColor: Colors.grey[400],
                            disabledTextColor: Colors.white,
                            textColor: Colors.white,
                            onPressed: (snapshot.data ?? false) &&
                                    _encryptMode != EncryptMode.rsa
                                ? () {
                                    _encryptMode = EncryptMode.aes;
                                    _doAESEncrypt();
                                  }
                                : null,
                            child: Text('Encrypt with AES'),
                          ),
                        ],
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
                                    onPressed: () {
                                      if (_encryptMode == EncryptMode.rsa) {
                                        _doRSADecrypt();
                                      } else if (_encryptMode ==
                                          EncryptMode.aes) {
                                        _doAESDecrypt();
                                      }
                                    },
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
    _rsaKeyPair = KeyPair.fromJwk(keyPairMap);
  }

  _loadAESKey() async {
    final secretKey = 'ubKq0tzN5a2OBGhB';
    _aesKeyPair =
        KeyPair.symmetric(SymmetricKey(keyValue: utf8.encode(secretKey)));
  }

  _doRSAEncrypt() async {
    final text = _plainTextController.text;
    final encryptedText = await _encryptRSA(text);
    print('RSA Encrypted Text: $encryptedText');
    _encryptedTextController.sink.add(encryptedText);
  }

  _doRSADecrypt() async {
    final decryptedText = await _decryptRSA(_encryptionResult);
    print('RSA Decrypted Text: $decryptedText');
    _decryptedTextController.add(decryptedText);
  }

  _doAESEncrypt() async {
    final text = _plainTextController.text;
    final encryptedText = await _encryptAES(text);
    print('AES Encrypted Text: $encryptedText');
    _encryptedTextController.sink.add(encryptedText);
  }

  _doAESDecrypt() async {
    final decryptedText = await _decryptAES(_encryptionResult);
    print('AES Decrypted Text: $decryptedText');
    _decryptedTextController.add(decryptedText);
  }

  _clear() {
    _plainTextController.clear();
    _buttonActiveController.add(false);
    _encryptedTextController.add(null);
    _decryptedTextController.add(null);
    _encryptionResult = null;
    _encryptMode = EncryptMode.non;
    setState(() {});
  }

  Future<String> _encryptRSA(String input) async {
    final encrypter =
        _rsaKeyPair.publicKey.createEncrypter(algorithms.encryption.rsa.pkcs1);
    _encryptionResult = encrypter.encrypt(Uint8List.fromList(input.codeUnits));
    return Base64Encoder().convert(_encryptionResult.data);
  }

  Future<String> _decryptRSA(EncryptionResult input) async {
    final decrypter =
        _rsaKeyPair.privateKey.createEncrypter(algorithms.encryption.rsa.pkcs1);
    final output = decrypter.decrypt(input);
    return String.fromCharCodes(output);
  }

  Future<String> _encryptAES(String input) async {
    final encrypter =
        _aesKeyPair.publicKey.createEncrypter(algorithms.encryption.aes.cbc);
    _encryptionResult = encrypter.encrypt(Uint8List.fromList(input.codeUnits),
        initializationVector: Uint8List.fromList(
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]));
    return Base64Encoder().convert(_encryptionResult.data);
  }

  Future<String> _decryptAES(EncryptionResult input) async {
    final decrypter =
        _aesKeyPair.privateKey.createEncrypter(algorithms.encryption.aes.cbc);
    final output = decrypter.decrypt(input);
    return String.fromCharCodes(output);
  }
}
