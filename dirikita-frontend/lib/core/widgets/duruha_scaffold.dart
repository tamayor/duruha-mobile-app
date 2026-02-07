import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_app_bar.dart'; // Adjust import path

class DuruhaScaffold extends StatelessWidget {
  final String? appBarTitle;
  final Widget? appBarTitleWidget;
  final List<Widget>? appBarActions;
  final PreferredSizeWidget? appBarBottom;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final bool isLoading;
  final Widget? loadingScreen;
  final bool safeAreaBottom;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const DuruhaScaffold({
    super.key,
    this.appBarTitle,
    this.appBarTitleWidget,
    this.appBarActions,
    this.appBarBottom,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.bottomSheet,
    this.isLoading = false,
    this.loadingScreen,
    this.safeAreaBottom = true,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    // Calculate total offset so content starts below the bar but background flows behind
    // Add bottom height if present
    final double appBarHeight =
        kToolbarHeight + (appBarBottom?.preferredSize.height ?? 0);
    final double appBarOffset = topPadding + appBarHeight;

    return Scaffold(
      // We extend the body so the blur has texture to process
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
      body: Stack(
        children: [
          // 1. CONTENT LAYER
          if (isLoading)
            loadingScreen ?? const Center(child: CircularProgressIndicator())
          else
            // We use a Container here to ensure the background covers the whole screen
            SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.only(top: appBarOffset),
                child: safeAreaBottom
                    ? SafeArea(top: false, child: body)
                    : body,
              ),
            ),

          // 2. GLASS APP BAR LAYER (Placed last to stay on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DuruhaAppBar(
              title: appBarTitle,
              titleWidget: appBarTitleWidget,
              actions: appBarActions,
              bottom: appBarBottom,
              showBackButton: showBackButton,
              onBackPressed: onBackPressed,
            ),
          ),
        ],
      ),
    );
  }
}
