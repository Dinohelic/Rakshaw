import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'app_text_field.dart';

class AppFilterBar extends StatelessWidget {
  final String searchHint;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget>? actions;

  const AppFilterBar({
    super.key,
    this.searchHint = 'Search...',
    this.searchController,
    this.onSearchChanged,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 780) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppSearchField(
                    hintText: searchHint,
                    controller: searchController,
                    onChanged: onSearchChanged,
                  ),
                  if (actions != null) ...[
                    ...actions!.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: action,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return Row(
            children: [
              AppSearchField(
                hintText: searchHint,
                controller: searchController,
                onChanged: onSearchChanged,
              ),
              const Spacer(),
              if (actions != null) ...[
                ...actions!.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: action,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
