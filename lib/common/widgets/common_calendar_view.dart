import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_rounded_button.dart';
import 'common_inkwell.dart';

class CommonCalendarView extends StatefulWidget {
  const CommonCalendarView({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: CommonCalendarView(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
          ),
        );
      },
    );
  }

  @override
  State<CommonCalendarView> createState() => _CommonCalendarViewState();
}

class _CommonCalendarViewState extends State<CommonCalendarView> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  DateTime get _firstDate => widget.firstDate ?? DateTime(1900, 1, 1);
  DateTime get _lastDate => widget.lastDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDate ??
        DateTime(now.year - 20, now.month, now.day);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  Future<void> _openMonthYearPicker() async {
    final picked = await _showMonthYearPicker(
      context,
      initialYear: _displayedMonth.year,
      initialMonth: _displayedMonth.month,
      firstYear: _firstDate.year,
      lastYear: _lastDate.year,
    );
    if (picked == null) return;

    setState(() {
      _displayedMonth = DateTime(picked.year, picked.month, 1);
      final lastDay = DateTime(picked.year, picked.month + 1, 0).day;
      final day = _selectedDate.day;
      final newDay = day.clamp(1, lastDay) as int;
      _selectedDate = DateTime(picked.year, picked.month, newDay);
    });
  }

  Future<DateTime?> _showMonthYearPicker(
    BuildContext context, {
    required int initialYear,
    required int initialMonth,
    required int firstYear,
    required int lastYear,
  }) {
    final years = List<int>.generate(
      lastYear - firstYear + 1,
      (i) => firstYear + i,
    );
    final months = List<int>.generate(12, (i) => i + 1);
    var yearIndex =
        years.indexOf(initialYear).clamp(0, years.length - 1) as int;
    var monthIndex = (initialMonth - 1).clamp(0, 11) as int;

    final yearController = FixedExtentScrollController(initialItem: yearIndex);
    final monthController = FixedExtentScrollController(initialItem: monthIndex);

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '연/월 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        CommonInkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              PhosphorIconsRegular.x,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: yearController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setSheetState(() => yearIndex = index);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: years.length,
                                builder: (context, index) {
                                  final isSelected = index == yearIndex;
                                  return Center(
                                    child: Text(
                                      '${years[index]}년',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.black.withOpacity(0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: monthController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setSheetState(() => monthIndex = index);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: months.length,
                                builder: (context, index) {
                                  final isSelected = index == monthIndex;
                                  return Center(
                                    child: Text(
                                      '${months[index]}월',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.black.withOpacity(0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CommonRoundedButton(
                      title: '확인',
                      onTap: () {
                        final selectedYear = years[yearIndex];
                        final selectedMonth = months[monthIndex];
                        Navigator.of(context).pop(
                          DateTime(selectedYear, selectedMonth, 1),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_CalendarCell> _buildCalendarCells() {
    final firstDayOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    final prevMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    final daysInPrevMonth = prevMonth.day;

    final cells = <_CalendarCell>[];
    for (var i = 0; i < startWeekday; i++) {
      final day = daysInPrevMonth - startWeekday + i + 1;
      cells.add(_CalendarCell(
        date: DateTime(prevMonth.year, prevMonth.month, day),
        isCurrentMonth: false,
      ));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(_CalendarCell(
        date: DateTime(_displayedMonth.year, _displayedMonth.month, day),
        isCurrentMonth: true,
      ));
    }
    while (cells.length % 7 != 0) {
      final nextIndex = cells.length - (startWeekday + daysInMonth) + 1;
      final nextMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
      cells.add(_CalendarCell(
        date: DateTime(nextMonth.year, nextMonth.month, nextIndex),
        isCurrentMonth: false,
      ));
    }
    while (cells.length < 42) {
      final last = cells.last.date;
      final next = last.add(const Duration(days: 1));
      cells.add(_CalendarCell(date: next, isCurrentMonth: false));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCalendarCells();
    final monthLabel = '${_displayedMonth.year}년 ${_displayedMonth.month}월';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '생년월일 변경',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              CommonInkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    PhosphorIconsRegular.x,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CommonInkWell(
                onTap: _openMonthYearPicker,
                child: Row(
                  children: [
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      PhosphorIconsRegular.caretDown,
                      size: 16,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CommonInkWell(
                onTap: _goToPreviousMonth,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    PhosphorIconsRegular.caretLeft,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
              CommonInkWell(
                onTap: _goToNextMonth,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayLabel('일'),
              _WeekdayLabel('월'),
              _WeekdayLabel('화'),
              _WeekdayLabel('수'),
              _WeekdayLabel('목'),
              _WeekdayLabel('금'),
              _WeekdayLabel('토'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              final cell = cells[index];
              final isSelected = _isSameDate(cell.date, _selectedDate);
              final isDisabled =
                  cell.date.isBefore(_firstDate) || cell.date.isAfter(_lastDate);
              final textColor = isSelected
                  ? Colors.white
                  : cell.isCurrentMonth
                      ? Colors.black
                      : Colors.black.withOpacity(0.35);
              final backgroundColor =
                  isSelected ? const Color(0xFF2EEA7B) : Colors.transparent;

              return GestureDetector(
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() => _selectedDate = cell.date);
                        Navigator.of(context).pop(cell.date);
                      },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cell.date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDisabled
                          ? Colors.black.withOpacity(0.2)
                          : textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _CalendarCell {
  _CalendarCell({
    required this.date,
    required this.isCurrentMonth,
  });

  final DateTime date;
  final bool isCurrentMonth;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
