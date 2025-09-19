import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Import screenutil
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:night_vigil/theme.dart';

class LoadingIndicator extends StatelessWidget {
  final double? size;
  const LoadingIndicator({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: AppColors.primary,
        // Use the provided size and make it responsive with .w (width-based scaling).
        // If no size is provided, default to a responsive size of 50.w.
        size: size?.w ?? 50.w,
      ),
    );
  }
}