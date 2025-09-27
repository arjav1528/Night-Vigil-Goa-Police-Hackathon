import 'package:app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';


class LoadingIndicator extends StatelessWidget {
  final double? size;
  const LoadingIndicator({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        
        color: AppColors.primary,
       
        size: size?.w ?? 50.w,
      ),
    );
  }
}