import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:retro/features/create/create_finish/create_finish_viewmodel.dart';
import 'package:retro/models/stage_entry.dart';
import 'package:retro/ui/components/custom_scaffold.dart';

class CreateFinishBottomBarModal extends StatefulWidget {
  const CreateFinishBottomBarModal({
    super.key,
    required this.bottomBar,
    required this.dismissCallback,
  });
  final Widget bottomBar;
  final Function dismissCallback;

  @override
  _CreateFinishBottomBarModalState createState() =>
      _CreateFinishBottomBarModalState();
}

class _CreateFinishBottomBarModalState
    extends State<CreateFinishBottomBarModal> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final viewModel = Provider.of<CreateFinishViewModel>(context);
    final i18n = AppLocalizations.of(context)!;
    viewModel.context = context;

    final widgets = <Widget>[];
    for (final key in viewModel.entries.keys) {
      final shouldPrependAlt =
          viewModel.entries[key].runtimeType == CustomTexturesEntry &&
              viewModel.prependAlt;
      widgets.add(Text("${shouldPrependAlt ? "alt/" : ""}$key",
          style: textTheme.titleSmall,),);
      widgets.addAll(
        viewModel.entries[key]!.iterables.map(
          (file) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  '\u2022 ${file.path}',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 20),
                child: IconButton(
                  iconSize: 20,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    viewModel.onRemoveFile(file, key);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        widget.bottomBar,
        Expanded(
          child: CustomScaffold(
            title: i18n.createFinishScreen_finish,
            subtitle: i18n.createFinishScreen_finishSubtitle,
            topRightWidget: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                widget.dismissCallback();
              },
            ),
            content: Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        prototypeItem: const SizedBox(height: 20),
                        children: widgets,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton(
                        onPressed: viewModel.entries.isNotEmpty
                            ? () {
                                viewModel.onGenerateOTR(widget.dismissCallback);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: Size(
                            MediaQuery.of(context).size.width * 0.5,
                            50,
                          ),
                        ),
                        child: viewModel.isGenerating
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${viewModel.filesProcessed}/${viewModel.totalFiles}',
                                  )
                                ],
                              )
                            : Text(i18n.createFinishScreen_generateOtr),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
