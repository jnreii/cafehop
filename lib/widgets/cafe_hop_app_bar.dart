import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cafehop/providers/theme_provider.dart';
import 'package:cafehop/themes.dart';

//consistent CafeHop AppBar used across the different screens
class CafeHopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final List<Widget>? actions;

  const CafeHopAppBar({
    this.showBackButton = false,
    this.actions,
  });

  static const double _bottomBorderWidth = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //gets the accent colour from the theme currently selected by the user
    final selectedTheme = ref.watch(themeProvider);

    return Container(
      decoration: BoxDecoration(
        color: selectedTheme.primary,
        border: Border(
          bottom: BorderSide(
            color: borderBlack,
            width: _bottomBorderWidth,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0, //no shadow
        centerTitle: true,
        automaticallyImplyLeading: false, //disables the default back button
        leading: showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: creamBackground,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            : null,

        //CafeHop logo with coffee icon and text
        title: Row(
          mainAxisSize: MainAxisSize.min, //only takes the space the title needs
          children: [
            Icon(
              Icons.coffee,
              color: creamBackground,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              'CafeHop',
              style: logoStyle.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: creamBackground,
              ),
            ),
          ],
        ),

        //some screens can pass their own action buttons here
        actions: actions,
      ),
    );
  }

  //PreferredSizeWidget needs the AppBar height
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + _bottomBorderWidth);
}