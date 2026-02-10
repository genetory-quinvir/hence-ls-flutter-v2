import 'package:flutter/material.dart';

import '../common/widgets/common_map_view.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CommonMapView(),
    );
  }
}
