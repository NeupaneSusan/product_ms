import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:product_ms/controller/CartController.dart';
import 'package:product_ms/controller/printController.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TakeAways extends StatefulWidget {
  final String userId;
  final String? remark;
  final String? twName;
  final String storeId;
  const TakeAways(
      {Key? key,
      required this.userId,
      this.remark,
      required this.storeId,
      this.twName})
      : super(key: key);

  @override
  State<TakeAways> createState() => _TakeAwaysState();
}

class _TakeAwaysState extends State<TakeAways> {
  double discount = 0.0;
  bool _isButtonDisabled = false;
  void toast(message, color) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        textColor: Colors.white,
        backgroundColor: color);
  }

  Future<void> checkout(discount) async {
    setState(() {
      _isButtonDisabled = true;
    });

    final cart = Provider.of<CartController>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String netAmount = (cart.totalAmount - discount).toStringAsFixed(2);
    var baseUrl = prefs.getString('baseUrl');
    var cartItems = [];
    cart.items.forEach((key, value) => {
          cartItems.add({
            'product_id': key,
            'quantity': value.quantity,
            'rate': value.rate,
            'amount': (value.quantity! * value.rate!).toStringAsFixed(2),
            'product_store_id': value.storeId,
          })
        });

    Map<String, String> header = {
      'Content-type': 'application/json',
      'Accept': 'application/json',
    };
    var orderUrl = '$baseUrl/api/twOrders/create';

    var body = jsonEncode(<String, dynamic>{
      "user_id": widget.userId,
      "gross_amount": (cart.totalAmount).toStringAsFixed(2),
      "discount": discount.toString(),
      "net_amount": netAmount,
      "tw_name": widget.twName,
      "store_id": widget.storeId,
      "remark": widget.remark,
      "take_away_items": cartItems
    });

    var res = await http.post(
      Uri.parse(orderUrl),
      headers: header,
      body: body,
    );

    if (res.statusCode == 200) {
      toast("Order Success", Colors.green);
      var data = jsonDecode(res.body)['data'];

      var result = await printingTokenTw(data, context, false);
      if (result) {
        toast('Printing T/W Token', Colors.blueAccent);
      } else {
        toast('Unable to Connected Printer', Colors.redAccent);
      }

      setState(() {
        _isButtonDisabled = false;
      });
      cart.clear();
      Navigator.of(context).pop(true);
    } else if (res.statusCode == 503) {
      var message = json.decode(res.body)['message'];
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text(message),
              actions: <Widget>[
                const SizedBox(width: 20.0),
                TextButton(
                    child: const Text("Close"),
                    onPressed: () {
                      Navigator.of(context).pop();
                      cart.clear();
                    }),
                const SizedBox(width: 180.0),
              ],
            );
          });

      setState(() {
        _isButtonDisabled = false;
      });
    } else {
      setState(() {
        _isButtonDisabled = false;
      });
      var jsonData = json.decode(res.body);
      toast(jsonData['message'].toString(), Colors.red);
    }

    setState(() {
      _isButtonDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isButtonDisabled;
      },
      child: Dialog(
        child: Consumer<CartController>(builder: (context, cartValue, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total amount : Rs ${(cartValue.totalAmount).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(
                    height: 10.0,
                  ),
                  const Text(
                    'Discount Amount',
                    style:
                        TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(
                    height: 10.0,
                  ),
                  StatefulBuilder(builder: (context, innerState) {
                    return Column(
                      children: [
                        TextFormField(
                            onChanged: (value) {
                              innerState(() {
                                discount = (value.isNotEmpty
                                    ? double.tryParse(value)
                                    : 0.0)!;
                              });
                            },
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Discount Amount',
                              contentPadding: const EdgeInsets.only(
                                bottom: 10.0,
                                left: 8,
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0)),
                            )),
                        const SizedBox(
                          height: 10.0,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total amount : Rs ${(cartValue.totalAmount - discount).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(
                          height: 10.0,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 35.0,
                              child: ElevatedButton(
                                child: const Text(
                                  'Back',
                                ),
                                style: ElevatedButton.styleFrom(
                                  primary: const Color(0xfff39c12),
                                ),
                                onPressed: _isButtonDisabled
                                    ? () {}
                                    : () {
                                        Navigator.pop(context);
                                      },
                              ),
                            ),
                            const SizedBox(
                              width: 0.0,
                            ),
                            SizedBox(
                              width: 180,
                              height: 35.0,
                              child: ElevatedButton(
                                child: const Text(
                                  'Order Now',
                                ),

                                // : const CircularProgressIndicator(
                                //     color: Colors.white,
                                //   ),
                                style: ElevatedButton.styleFrom(
                                  primary: Colors.teal,
                                ),
                                onPressed: _isButtonDisabled
                                    ? null
                                    : () {
                                        FocusScope.of(context)
                                            .requestFocus(FocusNode());

                                        checkout(discount);
                                      },
                              ),
                            )
                          ],
                        )
                      ],
                    );
                  })
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
