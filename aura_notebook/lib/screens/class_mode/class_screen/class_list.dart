part of 'class_screen.dart';

class _ClassList extends StatelessWidget {
  final List<ClassData> filtered;
  final ValueChanged<ClassData> onClassTap;
  final ValueChanged<ClassData> onClassDelete;

  const _ClassList({
    required this.filtered,
    required this.onClassTap,
    required this.onClassDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final columns = width >= 1020 ? 2 : 1;
        final maxContentWidth = columns == 2 ? 1180.0 : 800.0;
        final sideInset = width > maxContentWidth
            ? (width - maxContentWidth) / 2
            : 16.0;

        if (columns == 1) {
          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: sideInset),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClassCard(
                  data: filtered[i],
                  onTap: () => onClassTap(filtered[i]),
                  onDelete: () => onClassDelete(filtered[i]),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          sliver: SliverGrid.builder(
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 282,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
            ),
            itemBuilder: (_, i) => ClassCard(
              data: filtered[i],
              onTap: () => onClassTap(filtered[i]),
              onDelete: () => onClassDelete(filtered[i]),
            ),
          ),
        );
      },
    );
  }
}
