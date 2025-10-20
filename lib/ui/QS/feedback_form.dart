import 'dart:developer';

import 'package:flutter/material.dart';

class BeautifulFeedbackForm extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSubmit;

  const BeautifulFeedbackForm({super.key, this.onSubmit});

  @override
  _BeautifulFeedbackFormState createState() => _BeautifulFeedbackFormState();
}

class _BeautifulFeedbackFormState extends State<BeautifulFeedbackForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Feedback types
  final List<String> _feedbackTypes = [
    'Bug',
    'Suggestion',
    'Question',
    'Other'
  ];
  String _selectedFeedbackType = 'Bug';

  // Emoji rating
  final List<Map<String, String>> _emojiOptions = [
    {'emoji': '😞', 'label': 'Sad'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '😄', 'label': 'Very Happy'},
    {'emoji': '🤩', 'label': 'Awesome'},
  ];
  String? _selectedEmojiLabel;

  // What did you like options
  final List<String> _likedOptions = [
    'Question Quality',
    'Exam Interface',
    'Result Analysis',
    'History & Reports',
    'Speed & Performance',
    'Other',
  ];
  String? _selectedLikedOption;
  bool _showOtherLikedField = false;

  // Form fields
  String _feedbackMessage = '';
  String _otherLikedText = '';

  // Animation controller for smooth transition
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _starRating = 0;
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onLikedOptionChanged(String? value) {
    setState(() {
      _selectedLikedOption = value;
      if (value == 'Other') {
        _showOtherLikedField = true;
        _animationController.forward();
      } else {
        _showOtherLikedField = false;
        _animationController.reverse();
        _otherLikedText = '';
      }
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (userRating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a rating (emoji or stars).')),
        );
        return;
      }
      _formKey.currentState?.save();

      final feedbackData = {
        'type': _selectedFeedbackType,
        'rating': userRating,
        'QS': _feedbackMessage.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (widget.onSubmit != null) {
        widget.onSubmit!(feedbackData);
      }
      log(feedbackData.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your valuable QS!')),
      );

      // Reset form
      _formKey.currentState?.reset();
      setState(() {
        _selectedEmojiLabel = null;
        _selectedLikedOption = null;
        _showOtherLikedField = false;
        _selectedFeedbackType = 'Bug';
        _otherLikedText = '';
      });
      _animationController.reverse();
    }
  }

  Widget _buildEmojiRating() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojiOptions.map((option) {
          final isSelected = _selectedEmojiLabel == option['label'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedEmojiLabel = option['label'];
              });
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 250),
                  padding: EdgeInsets.all(isSelected ? 12 : 8),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? Colors.blue.shade100 : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    option['emoji']!,
                    style: TextStyle(
                      fontSize: 36,
                      color: isSelected ? Colors.blue : Colors.grey[600],
                    ),
                  ),
                ),

                SizedBox(height: 3),

                // Animated bounce label
                Visibility(
                  visible: isSelected,
                  child: AnimatedScale(
                    scale: isSelected ? 1.3 : 1.0,
                    duration: Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    child: Text(
                      option['label']!,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStarRatings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        int starIndex = index + 1;
        return IconButton(
          icon: Icon(
            starIndex <= _starRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
          onPressed: () {
            setState(() {
              _starRating = starIndex;
            });
          },
          tooltip: '$starIndex Star${starIndex > 1 ? "s" : ""}',
        );
      }),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        int starIndex = index + 1;
        bool isSelected = starIndex <= _starRating;

        return GestureDetector(
          onTap: () {
            setState(() {
              _starRating = starIndex;
            });
          },
          child: AnimatedScale(
            scale: isSelected ? 1.4 : 1.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: Icon(
              isSelected ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 32,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLikedDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What did you like?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          value: _selectedLikedOption,
          hint: Text('Select an option'),
          items: _likedOptions
              .map(
                (opt) => DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt),
                ),
              )
              .toList(),
          onChanged: _onLikedOptionChanged,
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please select an option.';
            }
            return null;
          },
          onSaved: (val) {
            _selectedLikedOption = val;
          },
        ),
        SizeTransition(
          sizeFactor: _fadeAnimation,
          axisAlignment: -1,
          child: _showOtherLikedField
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Please specify',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (val) {
                      if (_showOtherLikedField &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please specify what you liked.';
                      }
                      return null;
                    },
                    onSaved: (val) {
                      _otherLikedText = val ?? '';
                    },
                  ),
                )
              : SizedBox.shrink(),
        ),
      ],
    );
  }

  int userRating = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Feedback Type Dropdown
              Text('Feedback Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                value: _selectedFeedbackType,
                items: _feedbackTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedFeedbackType = val;
                    });
                  }
                },
                onSaved: (val) {
                  if (val != null) _selectedFeedbackType = val;
                },
              ),
              SizedBox(height: 28),

              // Emoji rating
              Text('How do you feel about the app?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              // _buildEmojiRating(), _buildStarRating(),
              StarRatingDemo(
                onRatingChanged: (rating) {
                  setState(() {
                    userRating = rating;
                  });
                  print('User selected rating: $rating');
                },
              ),

              SizedBox(height: 28),

              // Feedback Textarea
              Text('Your Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
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
                onSaved: (val) {
                  _feedbackMessage = val ?? '';
                },
              ),

              // Submit Button
              ElevatedButton.icon(
                icon: Icon(Icons.send),
                label: Text('Submit Feedback', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 3,
                ),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarRatingDemo extends StatefulWidget {
  final void Function(int rating)? onRatingChanged;

  const StarRatingDemo({Key? key, this.onRatingChanged}) : super(key: key);

  @override
  State<StarRatingDemo> createState() => _StarRatingDemoState();
}

class _StarRatingDemoState extends State<StarRatingDemo>
    with TickerProviderStateMixin {
  int _starRating = 0;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _rotationAnimations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _scaleAnimations = _controllers
        .map(
          (controller) => TweenSequence<double>(
            [
              TweenSequenceItem(
                tween: Tween(begin: 1.0, end: 1.8).chain(
                  CurveTween(curve: Curves.elasticOut),
                ),
                weight: 60,
              ),
              TweenSequenceItem(
                tween: Tween(begin: 1.8, end: 1.3).chain(
                  CurveTween(curve: Curves.easeInOut),
                ),
                weight: 40,
              ),
            ],
          ).animate(controller),
        )
        .toList();

    _rotationAnimations = _controllers
        .map(
          (controller) => TweenSequence<double>(
            [
              TweenSequenceItem(
                tween: Tween(begin: 0.0, end: 0.15).chain(
                  CurveTween(curve: Curves.easeOut),
                ),
                weight: 50,
              ),
              TweenSequenceItem(
                tween: Tween(begin: 0.15, end: 0.0).chain(
                  CurveTween(curve: Curves.easeInOut),
                ),
                weight: 50,
              ),
            ],
          ).animate(controller),
        )
        .toList();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStarTap(int starIndex) {
    setState(() {
      _starRating = starIndex;
    });
    widget.onRatingChanged?.call(_starRating);
    _controllers[starIndex - 1].forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          int starIndex = index + 1;
          bool isSelected = starIndex <= _starRating;

          return GestureDetector(
            onTap: () => _onStarTap(starIndex),
            child: AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                double scale = isSelected ? _scaleAnimations[index].value : 1.0;
                double rotation =
                    isSelected ? _rotationAnimations[index].value : 0.0;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        color: isSelected ? Colors.amber : Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
