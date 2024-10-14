import 'dart:async';

import 'package:flutter_quill/translations.dart';
import 'package:google_doc_clone/colors.dart';
import 'package:google_doc_clone/common/widgets/loader.dart';
import 'package:google_doc_clone/models/document_model.dart';
import 'package:google_doc_clone/models/error_model.dart';
import 'package:google_doc_clone/repository/auth_repository.dart';
import 'package:google_doc_clone/repository/document_repository.dart';
import 'package:google_doc_clone/repository/socket_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routemaster/routemaster.dart';
import 'package:together_ai_sdk/together_ai_sdk.dart';
import 'package:google_doc_clone/constants.dart';

final togetherAI = TogetherAISdk(apiKey);

class DocumentScreen extends ConsumerStatefulWidget {
  final String id;

  const DocumentScreen({super.key, required this.id});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  final TextEditingController titleController =
      TextEditingController(text: 'Untitled Document');
  quill.QuillController? _controller;
  ErrorModel? errorModel;
  final SocketRepository socketRepository = SocketRepository();

  @override
  void initState() {
    super.initState();
    socketRepository.joinRoom(widget.id);
    fetchDocumentData();

    // Move the changeListener setup to a separate method to allow re-initialization
    setupChangeListener();

    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_controller != null) {
        print("Auto-saving document..."); // Debugging line
        socketRepository.autoSave({
          'delta': _controller!.document.toDelta().toJson(),
          'room': widget.id,
        });
      }
    });
  }

  void setupChangeListener() {
    socketRepository.changeListener((data) {
      print("Received changed data: $data"); // Debugging line
      if (data["delta"] != null) {
        _controller?.compose(
          Delta.fromJson(data["delta"]),
          _controller?.selection ?? const TextSelection.collapsed(offset: 0),
          quill.ChangeSource.remote,
        );
      }
    });
  }

  Future<void> fetchDocumentData() async {
    errorModel = await ref.read(documentRepositoryProvider).getDocumentById(
          ref.read(userProvider)!.token,
          widget.id,
        );

    if (errorModel?.data != null) {
      titleController.text = (errorModel!.data as DocumentModel).title;
      _controller = quill.QuillController(
        document: errorModel!.data.content.isEmpty
            ? quill.Document()
            : quill.Document.fromDelta(
                Delta.fromJson(errorModel!.data.content),
              ),
        selection: const TextSelection.collapsed(offset: 0),
      );
      if (mounted) {
        setState(() {});
      }
    }

    _controller?.document.changes.listen((event) {
      if (event.source == quill.ChangeSource.local) {
        print("Local change detected: ${event.change}"); // Debugging line
        socketRepository.typing({
          'delta': event.change,
          'room': widget.id,
        });
      }
    });
  }

  Future<void> generateText(String prompt) async {
    try {
      final chatResponse = await togetherAI.chatCompletion([
        {'role': 'system', 'content': 'You are a helpful AI assistant.'},
        {'role': 'user', 'content': prompt},
      ], ChatModel.qwen15Chat72B);

      // Insert the generated text into the quill editor
      if (chatResponse.choices.isNotEmpty) {
        final generatedText = chatResponse.choices[0].message.content;
        _controller?.compose(
          Delta()..insert(generatedText),
          _controller?.selection ?? const TextSelection.collapsed(offset: 0),
          quill.ChangeSource.local,
        );
      }
    } catch (e) {
      print("Error generating text: $e");
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  void updateTitle(WidgetRef ref, String title) {
    ref.read(documentRepositoryProvider).updateTitle(
          token: ref.read(userProvider)!.token,
          id: widget.id,
          title: title,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(body: Loader());
    }
    return FlutterQuillLocalizationsWidget(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kWhiteColor,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                        text: 'http://localhost:3000/#/document/${widget.id}'))
                    .then(
                  (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copied!',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 10),
          ],
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Routemaster.of(context).replace('/');
                },
                child: Image.asset(
                  'assets/images/docs-logo.png',
                  height: 40,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: kBlueColor,
                      ),
                    ),
                    contentPadding: EdgeInsets.only(left: 10),
                    hintText: 'Untitled Document',
                  ),
                  onSubmitted: (value) => updateTitle(ref, value),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: kGreyColor,
                  width: 0.1,
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              quill.QuillToolbar.simple(controller: _controller!),
              const SizedBox(height: 10),
              Expanded(
                child: Card(
                  color: kWhiteColor,
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: quill.QuillEditor.basic(
                      controller: _controller!,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final prompt = await showDialog<String>(
              context: context,
              builder: (BuildContext context) {
                String userInput = '';
                return AlertDialog(
                  title: const Text('Enter your prompt'),
                  content: TextField(
                    onChanged: (value) {
                      userInput = value;
                    },
                    decoration: const InputDecoration(hintText: "Prompt"),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(userInput);
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                );
              },
            );

            if (prompt != null && prompt.isNotEmpty) {
              await generateText(prompt);
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
