import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/surveys/models/survey_question.dart';
import 'package:bus_app/features/surveys/services/survey_service.dart';
import 'package:bus_app/l10n/app_localizations.dart';
import 'package:bus_app/core/theme/app_theme.dart';

class SurveyPage extends StatefulWidget {
  final String? surveyId;

  const SurveyPage({super.key, this.surveyId});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _surveyService = Get.find<SurveyService>();
  final _pageController = PageController();
  final Map<String, String> _answers = {};
  int _currentPage = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.surveyId != null) {
        final survey = _surveyService.activeSurvey.value;
        if (survey == null || survey.id != widget.surveyId) {
          _surveyService.checkActiveSurvey();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submitAll() async {
    setState(() => _isSubmitting = true);
    await _surveyService.submitAllAnswers(_answers);
    if (mounted) Get.back(result: true);
  }

  bool _isCurrentMandatory() {
    final questions = _surveyService.questions;
    if (_currentPage >= questions.length) return false;
    return questions[_currentPage].isMandatory;
  }

  bool _hasCurrentAnswer() {
    final questions = _surveyService.questions;
    if (_currentPage >= questions.length) return false;
    return _answers[questions[_currentPage].id] != null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Obx(() {
      final questions = _surveyService.questions;
      final isLoading = _surveyService.isLoading.value;

      if (isLoading) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(title: Text(t.dailySurvey)),
            body: const Center(child: CircularProgressIndicator()),
          ),
        );
      }

      if (questions.isEmpty) {
        return PopScope(
          canPop: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.dailySurvey),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.dailySurvey,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Get.locale?.languageCode == 'ar'
                          ? 'لا توجد أسئلة نشطة في استبيان اليوم. يرجى المحاولة لاحقًا!'
                          : Get.locale?.languageCode == 'fr'
                              ? "Il n'y a pas de questions actives dans le sondage d'aujourd'hui. Veuillez réessayer plus tard !"
                              : "There are no active questions in today's survey. Please check back later!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        Get.locale?.languageCode == 'ar'
                            ? 'إغلاق'
                            : Get.locale?.languageCode == 'fr'
                                ? 'Fermer'
                                : 'Close',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final bool isSurveyMandatory = _surveyService.activeSurvey.value?.isMandatory ?? false;
      return _buildSurveyContent(t, questions, isSurveyMandatory);
    });
  }

  Widget _buildSurveyContent(AppLocalizations t, List<SurveyQuestion> questions, bool isSurveyMandatory) {

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!isSurveyMandatory) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.dailySurvey),
          leading: isSurveyMandatory ? const SizedBox.shrink() : IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(),
          ),
        ),
      body: Column(
        children: [
          if (questions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${t.question} ${_currentPage + 1} ${t.xOf} ${questions.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  if (_isCurrentMandatory())
                    Text(
                      '*',
                      style: TextStyle(color: Colors.red[700], fontSize: 16),
                    ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_currentPage + 1) / questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
            ),
          ],
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                return _QuestionCard(
                  question: questions[index],
                  locale: Get.locale?.languageCode ?? 'en',
                  onAnswer: (answer) => setState(() {
                    _answers[questions[index].id] = answer;
                  }),
                  initialAnswer: _answers[questions[index].id],
                );
              },
            ),
          ),
          _buildBottomNav(questions.length, t),
        ],
      ),
      ),
    );
  }

  Widget _buildBottomNav(int total, AppLocalizations t) {
    final isLast = _currentPage == total - 1;
    final canProceed = !_isCurrentMandatory() || _hasCurrentAnswer();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Text(t.previous),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (isLast) {
                        _submitAll();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  : null,
              child: isLast
                  ? (_isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(t.submit))
                  : Text(t.next),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.quitSurvey),
        content: Text(t.quitSurveyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.back();
            },
            child: Text(t.quit),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final SurveyQuestion question;
  final String locale;
  final Function(String) onAnswer;
  final String? initialAnswer;

  const _QuestionCard({
    required this.question,
    required this.locale,
    required this.onAnswer,
    this.initialAnswer,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  String? _selectedOption;
  double _rating = 0;
  double _sliderValue = 0;
  TextEditingController? _textController;
  TextEditingController? _numberController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialAnswer);
    _numberController = TextEditingController(text: widget.initialAnswer);
    if (widget.question.type == 'multiple_choice' || widget.question.type == 'yes_no') {
      _selectedOption = widget.initialAnswer;
    }
    if (widget.question.type == 'rating') {
      _rating = double.tryParse(widget.initialAnswer ?? '') ?? 0;
    }
    if (widget.question.type == 'slider') {
      _sliderValue = double.tryParse(widget.initialAnswer ?? '') ?? widget.question.min.toDouble();
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    _numberController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.locale == 'ar';
    final t = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question.getLocalizedText(widget.locale),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildInput(t),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(AppLocalizations t) {
    switch (widget.question.type) {
      case 'multiple_choice':
        return _buildMultipleChoice();
      case 'rating':
        return _buildRating(t);
      case 'numeric':
        return _buildNumeric(t);
      case 'yes_no':
        return _buildYesNo(t);
      case 'slider':
        return _buildSlider(t);
      default:
        return _buildText(t);
    }
  }

  Widget _buildMultipleChoice() {
    return Column(
      children: widget.question.options.map((option) {
        final isSelected = _selectedOption == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _selectedOption = option);
                widget.onAnswer(option);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(option)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRating(AppLocalizations t) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final star = index + 1;
            return IconButton(
              icon: Icon(
                star <= _rating ? Icons.star : Icons.star_border,
                color: star <= _rating ? Colors.amber : Colors.grey[300],
                size: 44,
              ),
              onPressed: () {
                setState(() => _rating = star.toDouble());
                widget.onAnswer(star.toString());
              },
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _rating > 0 ? '${_rating.toInt()} / 5' : t.tapToRate,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildNumeric(AppLocalizations t) {
    return TextField(
      controller: _numberController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: t.enterNumber,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (v) => widget.onAnswer(v),
    );
  }

  Widget _buildYesNo(AppLocalizations t) {
    return Row(
      children: [
        Expanded(
          child: _YesNoButton(
            label: t.yes,
            icon: Icons.check_circle_outline,
            isSelected: _selectedOption == 'yes',
            onTap: () {
              setState(() => _selectedOption = 'yes');
              widget.onAnswer('yes');
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _YesNoButton(
            label: t.no,
            icon: Icons.cancel_outlined,
            isSelected: _selectedOption == 'no',
            onTap: () {
              setState(() => _selectedOption = 'no');
              widget.onAnswer('no');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(AppLocalizations t) {
    final min = widget.question.min.toDouble();
    final max = widget.question.max.toDouble();
    return Column(
      children: [
        Text(
          _sliderValue.toInt().toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primaryBlue,
            inactiveTrackColor: AppTheme.primaryBlue.withOpacity(0.2),
            thumbColor: AppTheme.primaryBlue,
            overlayColor: AppTheme.primaryBlue.withOpacity(0.1),
            valueIndicatorColor: AppTheme.primaryBlue,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: _sliderValue,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            label: _sliderValue.toInt().toString(),
            onChanged: (v) {
              setState(() => _sliderValue = v);
              widget.onAnswer(v.toInt().toString());
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.toInt().toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            Text(t.slideToSelect,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            Text(max.toInt().toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildText(AppLocalizations t) {
    return TextField(
      controller: _textController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: t.typeAnswer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (v) => widget.onAnswer(v),
    );
  }
}

class _YesNoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _YesNoButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon, 
                size: 36, 
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[500]
              ),
              const SizedBox(height: 12),
              Text(
                label, 
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
                  fontSize: 16,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
