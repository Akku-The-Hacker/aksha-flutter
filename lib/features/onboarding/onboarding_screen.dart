import 'package:flutter/material.dart';
import '../../core/data/routine_templates.dart';
import '../../core/repositories/routine_repository.dart';
import '../../core/repositories/category_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final RoutineRepository _routineRepo = RoutineRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  
  int _currentPage = 0;
  bool _isLoading = false;
  
  // Selected templates to pre-populate
  final Set<RoutineTemplate> _selectedTemplates = {};

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Aksha',
      description: 'Track your routines honestly and build better habits.',
      icon: Icons.track_changes,
      color: const Color(0xFF6750A4),
    ),
    OnboardingPage(
      title: 'Stay Consistent',
      description: 'Complete daily tasks to maintain your streak and earn badges.',
      icon: Icons.local_fire_department,
      color: Colors.orange,
    ),
    OnboardingPage(
      title: 'Gain Insights',
      description: 'Visualize your progress with charts and calendar views.',
      icon: Icons.insights,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Get Started',
      description: 'Choose some starting routines or skip to create your own.',
      icon: Icons.rocket_launch,
      color: Colors.green,
    ),
  ];

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      // Create selected routines
      for (final template in _selectedTemplates) {
        // Ensure category exists
        final categoryId = await _categoryRepo.insert(template.category);
        
        // Create routine
        for (final routine in template.routines) {
          final newRoutine = routine.copyWith(categoryId: categoryId);
          await _routineRepo.insert(newRoutine);
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/signup');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  if (index == _pages.length - 1) {
                    return _buildTemplateSelectionPage(page);
                  }
                  return _buildPageContent(page);
                },
              ),
            ),
            
            // Navigation controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF6750A4)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  
                  // Next/Finish Button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_currentPage < _pages.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelectionPage(OnboardingPage page) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
         const SizedBox(height: 24),
         Text(
          page.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          page.description,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Popular Templates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...RoutineTemplateLibrary.templates.map((template) {
          final isSelected = _selectedTemplates.contains(template);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF6750A4)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            elevation: isSelected ? 4 : 1,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTemplates.remove(template);
                  } else {
                    _selectedTemplates.add(template);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: template.category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(template.category.iconName),
                            color: template.category.color,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            template.category.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6750A4),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: template.routines.map((r) {
                        return Chip(
                          label: Text(
                            r.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.grey[100],
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    // Simple mapping for demo purposes
    switch (iconName) {
      case 'fitness_center': return Icons.fitness_center;
      case 'meditation': return Icons.self_improvement; // closest to meditation
      case 'work': return Icons.work;
      case 'school': return Icons.school;
      case 'health_and_safety': return Icons.health_and_safety;
      default: return Icons.category;
    }
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
