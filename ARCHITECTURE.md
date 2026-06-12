PROJECT STRUCTURE:
lib/
  data/
    models/app_models.dart # Data classes (ItemPayload, GradingResult)
    repositories/mock_repository.dart # Mock backend for live presentation
  views/
    login_view.dart # Screen 1: Sign-up / Sign-in UI (No Sidebar)
    dashboard_layout.dart # The wrapper holding the Sidebar and Logout button
    submit_item_view.dart # Screen 2: Intake form inside Dashboard
    grading_result_view.dart # Screen 3: AI condition output inside Dashboard
    routing_decision_view.dart # Screen 4: Resell/Donate UI inside Dashboard
    health_card_view.dart # Screen 5: Digital certificate inside Dashboard
    history_view.dart # Screen 6: Data table inside Dashboard
  main.dart # App entry point, Amazon Theme, and routing setup