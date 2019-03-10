import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:store_owner/widgets/image_source_sheet.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProductScreen extends StatefulWidget {

  final DocumentSnapshot product;
  final String categoryId;

  ProductScreen({this.product, this.categoryId});

  @override
  _ProductScreenState createState() => _ProductScreenState(product, categoryId);
}

class _ProductScreenState extends State<ProductScreen> {

  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  DocumentSnapshot product;
  String categoryId;

  Map<String, dynamic> unsavedData;
  List<File> imagesToUpload = [];

  _ProductScreenState(this.product, this.categoryId);

  @override
  void initState() {
    super.initState();

    if(product != null){
      unsavedData = Map.of(product.data);
      unsavedData["images"] = List<String>.from(product.data["images"]);
    } else {
      unsavedData = {
        "images": [], "title": null, "description": null, "price": null
      };
    }
  }

  Future uploadImages(String productId) async {
    for(File img in imagesToUpload){
      StorageUploadTask uploadTask = FirebaseStorage.instance.ref().child(categoryId).
        child(productId).child(DateTime.now().millisecondsSinceEpoch.toString()).putFile(img);
      StorageTaskSnapshot s = await uploadTask.onComplete;
      String downloadUrl = await s.ref.getDownloadURL();
      unsavedData["images"].add(downloadUrl);
    }
    setState(() {
      imagesToUpload.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.product != null ? "Editar Produto" : "Criar Produto"),
        actions: <Widget>[
          product != null ?
            IconButton(
              icon: Icon(Icons.remove),
              onPressed: (){
                product.reference.delete();
                Navigator.of(context).pop();
              },
            ):
              Container(),
          IconButton(
            icon: Icon(Icons.save),
            color: Colors.white,
            onPressed: () async {
              if(_formKey.currentState.validate()){
                _formKey.currentState.save();

                ScaffoldFeatureController s = _scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text("Salvando produto...", style: TextStyle(color: Colors.white),),
                      duration: Duration(minutes: 1),
                      backgroundColor: Colors.pinkAccent,
                    )
                );

                try {
                  if(product != null) {
                    await uploadImages(product.documentID);
                    await product.reference.updateData(unsavedData);
                  } else {
                    DocumentReference d = await Firestore.instance.collection("products").document(
                        categoryId)
                        .collection("items").add(unsavedData);
                    await uploadImages(d.documentID);
                    await d.updateData(unsavedData);
                  }
                  s.close();
                  _scaffoldKey.currentState.showSnackBar(
                      SnackBar(content: Text("Produto salvo!", style: TextStyle(color: Colors.white),),
                        backgroundColor: Colors.pinkAccent,
                      )
                  );
                } catch (e){

                }
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(16),
          children: <Widget>[
            Text(
              "Imagens",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Container(
              height: 124,
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: unsavedData["images"].map<Widget>((i){
                  return Container(
                    height: 100,
                    width: 100,
                    margin: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      child: Image.network(i, fit: BoxFit.cover,),
                      onLongPress: (){
                        setState(() {
                          unsavedData["images"].remove(i);
                        });
                      },
                    )
                  );
                }).toList()..addAll(
                  imagesToUpload.map<Widget>((i){
                    return Container(
                        height: 100,
                        width: 100,
                        margin: EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          child: Image.file(i, fit: BoxFit.cover,),
                          onLongPress: (){
                            setState(() {
                              imagesToUpload.remove(i);
                            });
                          },
                        )
                    );
                  }).toList()
                )..add(
                  GestureDetector(
                    child: Container(
                      height: 100,
                      width: 100,
                      child: Icon(Icons.camera_enhance, color: Colors.white,),
                      color: Colors.white.withAlpha(50),
                    ),
                    onTap: (){
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => ImageSourceSheet((image){
                          Navigator.of(context).pop();
                          setState(() {
                            imagesToUpload.add(image);
                          });
                        })
                      );
                    },
                  )
                ),
              ),
            ),
            SizedBox(height: 16,),
            TextFormField(
              style: TextStyle(color: Colors.white,
                  fontSize: 16),
              decoration: InputDecoration(
                  hintText: "Título",
                  hintStyle: TextStyle(color: Colors.grey),
              ),
              initialValue: unsavedData["title"],
              onSaved: (text){unsavedData["title"] = text;},
              validator: (text){
                if(text.trim().isEmpty) return "Preencha o título do produto";
              },
            ),
            TextFormField(
              style: TextStyle(color: Colors.white,
                  fontSize: 16),
              maxLines: 6,
              decoration: InputDecoration(
                  hintText: "Descrição",
                  hintStyle: TextStyle(color: Colors.grey)
              ),
              initialValue: unsavedData["description"],
              onSaved: (text){unsavedData["description"] = text;},
              validator: (text){
                if(text.trim().isEmpty) return "Preencha a descrição do produto";
              },
            ),
            TextFormField(
              style: TextStyle(color: Colors.white,
                  fontSize: 16),
              decoration: InputDecoration(
                  hintText: "Preço",
                  hintStyle: TextStyle(color: Colors.grey)
              ),
              keyboardType: TextInputType.number,
              initialValue: unsavedData["price"]?.toStringAsFixed(2),
              onSaved: (text){unsavedData["price"] = double.parse(text);},
              validator: (text){
                try{
                  double price = double.parse(text);
                  if(price.toString().split(".")[1].length != 2)
                    return "Utilize 2 casas decimais";
                } catch (e) {
                  return "Preço inválido";
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}