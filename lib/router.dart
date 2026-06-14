import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'RoleSelectionScreen.dart';
import 'SellerTypeScreen.dart';
import 'SellIntroScreen.dart';
import 'BuyerDashboard.dart';
import 'MarketplaceTab.dart';
import 'ReservedTab.dart';
import 'PurchasesTab.dart';
import 'NotificationsTab.dart';
import 'ListingDetailScreen.dart';
import 'views/login_view.dart';
import 'views/seller_shell.dart';
import 'views/submit_item_view.dart';
import 'views/grading_result_view.dart';
import 'views/routing_decision_view.dart';
import 'views/health_card_view.dart';
import 'views/history_view.dart';
import 'data/models/evaluation_input.dart';

/// URL-based navigation so every screen, buyer tab, and seller wizard step has
/// its own address — making the browser back/forward arrows (and refresh) work
/// across the whole app.
///
/// Route map:
///   /                       role selection (main menu)
///   /login?entry=...        Cognito auth
///   /sell                   seller type chooser
///   /sell/intro             consumer sell intro
///   /buyer/market           ┐
///   /buyer/reserved         │ buyer dashboard tabs (StatefulShellRoute)
///   /buyer/purchases        │
///   /buyer/notifications    ┘
///   /listing/:id            listing detail + Health Card
///   /seller/grade           ┐
///   /seller/history         │ seller dashboard (ShellRoute: sidebar + top bar)
///   /seller/grade/result    │  wizard steps carry the EvaluationInput via extra
///   /seller/grade/route     │
///   /seller/grade/health    │
///   /seller/history/health  ┘ (read-only Health Card from history)

LoginEntry _entryFromString(String? s) {
  switch (s) {
    case 'warehouseSell':
      return LoginEntry.warehouseSell;
    case 'customerSell':
      return LoginEntry.customerSell;
    default:
      return LoginEntry.buyer;
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const RoleSelectionScreen()),
    GoRoute(
      path: '/login',
      builder: (c, s) =>
          LoginView(entry: _entryFromString(s.uri.queryParameters['entry'])),
    ),
    GoRoute(path: '/sell', builder: (c, s) => const SellerTypeScreen()),
    GoRoute(path: '/sell/intro', builder: (c, s) => const SellIntroScreen()),

    // ── Buyer dashboard: 4 tabs, each its own URL, state preserved ──
    StatefulShellRoute.indexedStack(
      builder: (c, s, navigationShell) =>
          BuyerDashboard(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/market',
              builder: (c, s) => const MarketplaceTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/reserved',
              builder: (c, s) => const ReservedTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/purchases',
              builder: (c, s) => const PurchasesTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/buyer/notifications',
              builder: (c, s) => const NotificationsTab(),
            ),
          ],
        ),
      ],
    ),

    // ── Listing detail (full screen, above the shells) ──
    GoRoute(
      path: '/listing/:id',
      builder: (c, s) {
        final extra = s.extra is Map ? s.extra as Map : const {};
        return ListingDetailScreen(
          listingId: s.pathParameters['id']!,
          purchaseStatus: extra['purchaseStatus'] as String?,
          purchaseDate: extra['purchaseDate'] as DateTime?,
        );
      },
    ),

    // ── Seller dashboard: sidebar + top bar shell, content from child route ──
    ShellRoute(
      builder: (c, s, child) => SellerShell(child: child),
      routes: [
        GoRoute(
          path: '/seller/grade',
          builder: (c, s) => const SubmitItemView(),
        ),
        GoRoute(
          path: '/seller/history',
          builder: (c, s) => HistoryView(key: UniqueKey()),
        ),
        GoRoute(
          path: '/seller/grade/result',
          builder: (c, s) =>
              GradingResultView(evaluation: s.extra as EvaluationInput?),
        ),
        GoRoute(
          path: '/seller/grade/route',
          builder: (c, s) =>
              RoutingDecisionView(evaluation: s.extra as EvaluationInput?),
        ),
        GoRoute(
          path: '/seller/grade/health',
          builder: (c, s) =>
              HealthCardView(evaluation: s.extra as EvaluationInput?),
        ),
        GoRoute(
          path: '/seller/history/health',
          builder: (c, s) => HealthCardView(
            evaluation: s.extra as EvaluationInput?,
            readOnly: true,
          ),
        ),
      ],
    ),
  ],
);
