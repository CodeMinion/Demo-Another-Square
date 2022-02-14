import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:another_brother/label_info.dart';
import 'package:another_brother/printer_info.dart';
import 'package:another_square/another_square.dart';
import 'package:another_square/square_models.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Square Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Completer<WebViewController> _controller =
  Completer<WebViewController>();


  // IMPORTANT: When trying to access the sadnbox oauth in Square
  // through the mobile device it fails to get past "To start OAuth flow
  // for a sandbox account." So for development using the sandbox it's
  // recommended to user an auth token directly and bypass the OAuth flow.
  // For Production that problem doesn't happen.
  // Found in https://developer.squareup.com/apps/
  final String applicationId = <application id>;
  final String clientId = <application id>;
  final String clientSecret = <application secrete>;
  ///final String refreshToken = "EQAAENfNieufQblDRPhuWTDJicWLTlgoPTFJctN_OfokyNLve9fxD6yWOmuY1QWf";
  final String authToken = "EAAAENBS3PLg1fNJoLZ72y3g-uwtloX3Lmmj5YQuskG4tcXKIKH7xGmHpfYJ7fh0";


  // Configured in Square Dashboard.
  final String redirectUrl =
      "https://localhost";

  SquareClient? squareClient;
  String? authUrl = "";
  TokenResponse? token;

  ByteData? receiptPreview;
  
  @override
  void initState() {
    print("Init Called");
    initializeQuickbooks();
  }
  ///
  /// Initialize Quickbooks Client
  ///
  Future<void> initializeQuickbooks() async {
    squareClient = SquareClient(
        applicationId: applicationId,
        clientId: clientId,
        clientSecret: clientSecret,
        environmentType: EnvironmentType.Sandbox);

    await squareClient!.initialize();
    setState(() {
      authUrl = squareClient!.getAuthorizationPageUrl(
          scopes: [Scope.OrdersRead, Scope.OrdersWrite],
          redirectUrl: redirectUrl,
          state: "state123");

    });
  }

  Future<void> requestAccessToken(String code) async {
    token = await squareClient!.getAuthToken(code: code,
        redirectUrl: redirectUrl,
        );

    setState(() {

    });
  }

  Future<void> printQuickbooksReport() async {

    //////////////////////////////////////////////////
    /// Request the Storage permissions required by
    /// another_brother to print.
    //////////////////////////////////////////////////
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Access to storage is needed in order print."),
        ),
      ));
      return;
    }

    //////////////////////////////////////////////////
    /// Create an order
    //////////////////////////////////////////////////
    var createdOrd = await squareClient!.createOrder(
        //authToken: authToken,
        request: CreateOrderRequest.fromJson({
          "idempotency_key": "C8193148c-9586-11e6-99f9-28cfe92138cf",
          "order": {
            "reference_id": "my-order-001",
            "location_id": "LPYKKD4HSCRGP", //"LZM0BVPKR59NK",
            "line_items": [
              {
                "name": "New York Strip Steak",
                "quantity": "1",
                "base_price_money": {
                  "amount": 1599,
                  "currency": "USD"
                }
              },
              {
                "name": "Oranges",
                "quantity": "2",
                "base_price_money": {
                  "amount": 1599,
                  "currency": "USD"
                }
              },
              {
                "name": "Other Item",
                "quantity": "2",
                "base_price_money": {
                  "amount": 999,
                  "currency": "USD"
                }
              },
            ],
            "taxes": [
              {
                "uid": "state-sales-tax",
                "name": "State Sales Tax",
                "percentage": "9",
                "scope": "ORDER"
              }
            ],
          }
        }));

    //////////////////////////////////////////////////
    /// Convert order to Image
    //////////////////////////////////////////////////
    ui.Image imageToPrint = await _generateReceipt(createdOrd);
    receiptPreview = await _getWidgetImage(createdOrd);

    setState(() {
    });

    //////////////////////////////////////////////////
    /// Configure printer
    /// Printer: QL1110NWB
    /// Connection: Bluetooth
    /// Paper Size: W62
    /// Important: Printer must be paired to the
    /// phone for the BT search to find it.
    //////////////////////////////////////////////////
    var printer = Printer();
    var printInfo = PrinterInfo();
    printInfo.printerModel = Model.QL_1110NWB;
    printInfo.printMode = PrintMode.FIT_TO_PAGE;
    printInfo.isAutoCut = true;
    printInfo.port = Port.BLUETOOTH;
    // Set the label type.
    printInfo.labelNameIndex = QL1100.ordinalFromID(QL1100.W62.getId());

    // Set the printer info so we can use the SDK to get the printers.
    await printer.setPrinterInfo(printInfo);

    // Get a list of printers with my model available in the network.
    List<BluetoothPrinter> printers = await printer.getBluetoothPrinters([Model.QL_1110NWB.getName()]);

    if (printers.isEmpty) {
      // Show a message if no printers are found.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("No paired printers found on your device."),
        ),
      ));

      return;
    }
    // Get the IP Address from the first printer found.
    printInfo.macAddress = printers.single.macAddress;
    printer.setPrinterInfo(printInfo);

    // Print Invoice
    PrinterStatus status = await printer.printImage(imageToPrint);

    if (status.errorCode != ErrorCode.ERROR_NONE) {
      // Show toast with error.
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Print failed with error code: ${status.errorCode.getName()}"),
        ),
      ));

    }
  }

  Future<ui.Image> _generateReceipt(Order order) async {
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);

    double baseSize = 200;
    double labelWidthPx = 9 * baseSize;
    //double labelHeightPx = 3 * baseSize;
    //double qrSizePx = labelHeightPx / 2;

    // Start Padding of the QR Code
    double qrPaddingStart = 30;
    // Start Padding of the Paragraph in relation to the QR Code
    double paraPaddingStart = 30;
    // Font Size for largest text
    double primaryFontSize = 100;


    // Create Paragraph
    ui.ParagraphBuilder paraBuilder = ui.ParagraphBuilder(new ui.ParagraphStyle(textAlign: TextAlign.start));

    order.lineItems?.forEach((lineItem) {
      // Add heading to paragraph
      paraBuilder.pushStyle(ui.TextStyle(fontSize: primaryFontSize, color: Colors.black, fontWeight: FontWeight.bold));
      paraBuilder.addText("${lineItem.name} x ${lineItem.quantity}\t\t \$${(lineItem.totalMoney!.amount!)/100.0}\n");
      paraBuilder.pop();
    });
    paraBuilder.pushStyle(ui.TextStyle(fontSize: primaryFontSize, color: Colors.black, fontWeight: FontWeight.bold));
    paraBuilder.addText("\nTotal: \$${order.totalMoney!.amount!/100.0}");
    paraBuilder.pop();

    Offset paraOffset = Offset.zero;
    ui.Paragraph infoPara = paraBuilder.build();
    // Layout the pargraph in the remaining space.
    infoPara.layout(ui.ParagraphConstraints(width: labelWidthPx));

    Paint paint = new Paint();
    paint.color = Color.fromRGBO(255, 255, 255, 1);
    Rect bounds = new Rect.fromLTWH(0, 0, labelWidthPx, infoPara.height);
    canvas.save();
    canvas.drawRect(bounds, paint);

    // Draw paragrpah on canvas.
    canvas.drawParagraph(infoPara, paraOffset);

    var picture = await recorder.endRecording().toImage(9 * 200, 3 * 200);

    return picture;
  }

  Future<ByteData> _getWidgetImage(Order order) async {
    ui.Image generatedImage = await _generateReceipt(order);
    ByteData? bytes = await generatedImage.toByteData(format: ui.ImageByteFormat.png);
    return bytes!;
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: token == null ? WebView(
            key: ObjectKey(authUrl),
            initialUrl: authUrl,
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (WebViewController webViewController) {
              _controller.complete(webViewController);
            },
            onProgress: (int progress) {
              print('WebView is loading (progress : $progress%)');
            },
            javascriptChannels: <JavascriptChannel>{},
            navigationDelegate: (NavigationRequest request) {
              if (request.url.startsWith(redirectUrl)) {
                print('blocking navigation to $request}');
                var url = Uri.parse(request.url);
                String code = url.queryParameters["code"]!;
                // Request access token
                requestAccessToken(code);

                return NavigationDecision.prevent;
              }
              print('allowing navigation to $request');
              return NavigationDecision.navigate;
            },
            onPageStarted: (String url) {
              print('Page started loading: $url');
            },
            onPageFinished: (String url) {
              print('Page finished loading: $url');
            },
            gestureNavigationEnabled: true,
            backgroundColor: const Color(0x00000000),
          ): (receiptPreview != null ? Image.memory(receiptPreview!.buffer.asUint8List()) :Container(child: Text("Authenticated with Square"),))
      ),
      floatingActionButton: token != null ? FloatingActionButton(
        onPressed: (){printQuickbooksReport();},
        tooltip: 'Print',
        child: const Icon(Icons.print),
      ): null, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}