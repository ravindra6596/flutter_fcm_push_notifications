import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// -----------------------------------------
/// CONTROLLER
/// -----------------------------------------
class FeedbackController extends GetxController
    with GetTickerProviderStateMixin {
  // Reactive variables
  final feedbackTypes = [
    'Bug',
    'Suggestion',
    'Question',
    'Feature Request',
    'Usability Issue',
    'Performance',
    'Content/MCQ Quality',
    'Other'
  ];

  var selectedFeedbackType = 'Bug'.obs;
  var starRating = 1.obs;
  var feedbackText = ''.obs;

  // Animation Controllers
  late List<AnimationController> controllers;
  late List<Animation<double>> scaleAnimations;
  late List<Animation<double>> rotationAnimations;

  final formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    resetForm();
    controllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    scaleAnimations = controllers
        .map(
          (c) => TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.8)
                  .chain(CurveTween(curve: Curves.elasticOut)),
              weight: 60,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.8, end: 1.3)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 40,
            ),
          ]).animate(c),
        ).toList();

    rotationAnimations = controllers
        .map(
          (c) => TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 0.15)
                  .chain(CurveTween(curve: Curves.easeOut)),
              weight: 50,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.15, end: 0.0)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 50,
            ),
          ]).animate(c),
        ).toList();
  }

  void updateStarRating(int rating) {
    starRating.value = rating;
    controllers[rating - 1].forward(from: 0.0);
  }

  void updateFeedbackType(String type) {
    selectedFeedbackType.value = type;
  }
  @override
  void onReady() {
    super.onReady();
    resetForm();
  }
  void submitFeedback() {
    if (formKey.currentState?.validate() ?? false) {
      formKey.currentState?.save();
      final feedbackData = {
        'type': selectedFeedbackType.value,
        'rating': starRating.value,
        'QS': feedbackText.value.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      log(feedbackData.toString());

      // Reset form
      resetForm();
    }
  }
  void resetForm() {
    starRating.value = 1;
    feedbackText.value = '';
    selectedFeedbackType.value = 'Bug';
  }
  @override
  void onClose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.onClose();
  }
}

/// -----------------------------------------
/// MAIN FEEDBACK FORM WIDGET
/// -----------------------------------------
class FeedbackFormGetX extends StatefulWidget {
  const FeedbackFormGetX({super.key});

  @override
  State<FeedbackFormGetX> createState() => _FeedbackFormGetXState();
}

class _FeedbackFormGetXState extends State<FeedbackFormGetX> {
  final FeedbackController controller = Get.put(FeedbackController(),permanent: false);

  final feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.resetForm();
    feedbackController.clear();
  }

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Form'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Feedback Type Dropdown
              const Text(
                'Feedback Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Obx(
                () => ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButtonFormField<String>(
                    isDense: true,
                    borderRadius:BorderRadius.circular(10),
                    value: controller.selectedFeedbackType.value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    ),
                    items: controller.feedbackTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.updateFeedbackType(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),

              /// Star Rating
              const Text(
                'Rate your experience',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    int starIndex = index + 1;
                    bool isSelected = starIndex <= controller.starRating.value;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => controller.updateStarRating(starIndex),
                        child: AnimatedBuilder(
                          animation: controller.controllers[index],
                          builder: (context, child) {
                            double scale = isSelected
                                ? controller.scaleAnimations[index].value
                                : 1.0;
                            double rotation = isSelected
                                ? controller.rotationAnimations[index].value
                                : 0.0;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Transform.rotate(
                                angle: rotation * math.pi,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    isSelected ? Icons.star : Icons.star_border,
                                    color:
                                        isSelected ? Colors.amber : Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),

              /// Feedback Text Field
              const Text(
                'Your Feedback',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  hintText: 'Tell us your thoughts...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Please enter at least 10 characters.';
                  }
                  return null;
                },
                onSaved: (val) => controller.feedbackText.value = val ?? '',
              ),
              const SizedBox(height: 24),

              /// Submit Button
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Feedback',
                      style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 3,
                  ),
                  onPressed: () {
                    controller.submitFeedback();
                    feedbackController.text = '';
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
