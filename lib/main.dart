import 'package:android_jarvis_interface/linker_service.dart';
import 'package:android_jarvis_interface/text_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MaterialApp(
    title: 'Jarvis Interface',
    darkTheme: darkTheme,
    themeMode: ThemeMode.dark,
    home: const HomePage(),
  ));
}

ThemeData darkTheme = ThemeData.dark();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final TextEditingController textFieldControl;
  FocusNode textFocus = FocusNode();

  List<TextBubble> bubbles = <TextBubble>[], animatedBubbles = <TextBubble>[];
  bool canSend = true;

  final GlobalKey<AnimatedListState> listKey = GlobalKey();

  @override
  void initState() {
    textFocus.addListener(textFieldFocusChange);
    textFieldControl = TextEditingController();
    linkerPingLoop();
    super.initState();
  }

  @override
  void dispose() {
    textFocus.removeListener(textFieldFocusChange);
    textFocus.dispose();
    textFieldControl.dispose();
    super.dispose();
  }

  void linkerPingLoop() async {
    while (true) {
      var newRequests = await Linker.getRequests();
      var newResponses = await Linker.getResponses();
      List<TextBubble> textBubbles = <TextBubble>[];
      for (var i = 0; i < newRequests.length; i++) {
        textBubbles.insert(0, TextBubble(newRequests[i].id ?? -1,
            false, newRequests[i].request ?? '<Null>', ''));
      }
      for (var i = 0; i < textBubbles.length; i++) {
        for (var r = 0; r < newResponses.length; r++) {
          if (newResponses[r].requestId == textBubbles[i].requestId) {
            textBubbles.insert(i + 1, TextBubble(-1, true,
                newResponses[r].data ?? '<Null>',
                newResponses[r].origin ?? '<Null>'));
            i++;
            break;
          }
        }
      }

      setState(() {
        bubbles = textBubbles.reversed.toList();
        animateList();
      });
      await Future.delayed(const Duration(milliseconds: 1250));
    }
  }

  bool compareBubbles(TextBubble a, TextBubble b) {
    return a.isResponse == b.isResponse && a.origin == b.origin &&
        a.message == b.message && a.requestId == b.requestId;
  }

  void animateList() {
    if (bubbles.length > animatedBubbles.length) {
      for (var i = 0; i < bubbles.length; i++) {
        if (animatedBubbles.length <= i) {
          addListItem(i, bubbles[i]);
        } else if (!compareBubbles(bubbles[i], animatedBubbles[i])) {
          addListItem(i, bubbles[i]);
        }
      }
    } else if (bubbles.length < animatedBubbles.length) {
      for (var i = animatedBubbles.length - 1; i >= 0; i--) {
        if (bubbles.length <= i) {
          removeListItem(i);
        } else if (!compareBubbles(bubbles[i], animatedBubbles[i])) {
          removeListItem(i);
        }
      }
    } else {

    }
  }

  void addListItem(int index, TextBubble bubble) {
    animatedBubbles.insert(index, bubble);
    listKey.currentState!.insertItem(index,
      duration: const Duration(milliseconds: 500)
    );
  }

  void removeListItem(int index) {
    listKey.currentState!.removeItem(index, (_, animation) {
      return FadeTransition(
        opacity: animation,
        child: Container(),
      );
    }, duration: const Duration(seconds: 0));
    animatedBubbles.removeAt(index);
  }

  void textFieldFocusChange() {
    debugPrint(textFocus.hasPrimaryFocus.toString());
  }

  void onPressSendButton(String text) async {
    if (canSend && text.isNotEmpty) {
      canSend = false;
      textFieldControl.clear();
      await Linker.sendRequest(text);
      linkerPingLoop();
      canSend = true;
    }
  }

  Widget buildChatBubble(TextBubble bubble) {
    bool isResponse = bubble.isResponse;
    return Column(
      children: [
        if (isResponse)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(bubble.origin)
          )
        else
          Container(),
        Align(
          alignment: isResponse ? Alignment.centerLeft : Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isResponse ? const LinearGradient(
                colors: [Colors.white24, Colors.white24],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ) : const LinearGradient(
                colors: [Colors.indigo, Colors.indigoAccent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: const Radius.circular(50),
                bottomRight: const Radius.circular(50),
                topLeft: isResponse ? const Radius.circular(5)
                    : const Radius.circular(50),
                topRight: isResponse ? const Radius.circular(50)
                    : const Radius.circular(5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                bubble.message,
                style: Theme.of(context).textTheme.bodyText1!.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> buildTextField() {
    return [
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 50,
          child: TextField(
            textAlignVertical: TextAlignVertical.center,
            autocorrect: true,
            controller: textFieldControl,
            focusNode: textFocus,
            onTap: textFieldFocusChange,
            cursorColor: Colors.white,
            keyboardAppearance: Brightness.dark,
            onSubmitted: (text) => onPressSendButton(text),
            style: const TextStyle(
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              hintText: 'Write message...',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
              border: InputBorder.none
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        height: 35,
        width: 35,
        child: FloatingActionButton(
          onPressed: () => onPressSendButton(textFieldControl.text),
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 10),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.zero,
          right: Radius.circular(50),
        ),
        child: Drawer(
          child: ListView(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.black38,
                ),
                padding: EdgeInsets.all(15),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    "Menu",
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),
                ),
              ),
              ListTile(
                subtitle: const Text(
                  "Show more information about this app",
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
                title: const Text(
                  "About",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: "Jarvis Interface",
                  applicationVersion: "0.1.1",
                  children: [
                    const Text("Jarvis interfaces such as these allow the user"
                        " to talk to the Jarvis AI system."),
                  ],
                ),
              )
            ],
          )
        ),
      ),
      body: Stack(
        children: [
          AnimatedList(
            initialItemCount: 0,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 70),
            physics: const BouncingScrollPhysics(),
            key: listKey,
            itemBuilder: (_, index, animation) {
              return SizeTransition(
                key: UniqueKey(),
                sizeFactor: animation.drive(
                  CurveTween(curve: Curves.fastOutSlowIn)
                ),
                child: ScaleTransition(
                  key: UniqueKey(),
                  alignment: animatedBubbles[index].isResponse
                    ? Alignment.topLeft
                    : Alignment.topRight,
                  scale: animation.drive(
                    CurveTween(curve: Curves.fastOutSlowIn)
                  ),
                  child: buildChatBubble(animatedBubbles[index]),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  color: darkTheme.cardColor,
                  child: Row(
                    children: buildTextField(),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 80,
              child: AppBar(
                title: const Text('Jarvis'),
                elevation: 8,
                backgroundColor: darkTheme.bottomAppBarColor.withAlpha(
                  Color.getAlphaFromOpacity(0.9)
                ),
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

