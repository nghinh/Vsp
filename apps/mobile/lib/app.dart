import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_bloc.dart';

class VspApp extends StatefulWidget {
  const VspApp({super.key, this.authBloc});

  final AuthBloc? authBloc;

  @override
  State<VspApp> createState() => _VspAppState();
}

class _VspAppState extends State<VspApp> {
  late final AuthBloc _authBloc;
  late final bool _ownsAuthBloc;

  @override
  void initState() {
    super.initState();
    _ownsAuthBloc = widget.authBloc == null;
    _authBloc = widget.authBloc ?? _createAuthBloc();
    _authBloc.add(const SessionRestoreRequested());
  }

  AuthBloc _createAuthBloc() {
    final apiClient = ApiClient();
    return AuthBloc(
      authRepository: AuthRepository(
        authService: AuthService(apiClient: apiClient),
        secureStorage: SecureStorage(),
        apiClient: apiClient,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsAuthBloc) {
      _authBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp(
        title: 'Vietnam Smart Golf',
        debugShowCheckedModeBanner: false,
        theme: _buildVspTheme(),
        home: const AuthStartupGate(),
      ),
    );
  }
}

class AuthStartupGate extends StatelessWidget {
  const AuthStartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is SessionRestored || state is AuthSuccess) {
          return const _PreviewShell();
        }
        if (state is SessionNotFound ||
            state is AuthFailure ||
            state is AuthInitial) {
          return const _AuthEntryScreen();
        }
        return const _SessionStartupView();
      },
    );
  }
}

ThemeData _buildVspTheme() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFFFB599),
    onPrimary: Color(0xFF5A1C00),
    secondary: Color(0xFFFFB690),
    onSecondary: Color(0xFF552100),
    surface: Color(0xFF0B1326),
    onSurface: Color(0xFFDAE2FD),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    fontFamily: 'Fira Sans',
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF2D3449),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: const Color(0xFFEC6A06),
        foregroundColor: const Color(0xFF4A1C00),
      ),
    ),
  );
}

class _AuthEntryScreen extends StatefulWidget {
  const _AuthEntryScreen();

  @override
  State<_AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends State<_AuthEntryScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _identifierError = identifier.isEmpty
          ? 'Enter your phone or email'
          : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_identifierError == null && _passwordError == null) {
      context.read<AuthBloc>().add(
        LoginRequested(identifier: identifier, password: password),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sports_golf,
                    size: 64,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'Vietnam Smart Golf',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vietnam Smart Golf',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Phone or email',
                      errorText: _identifierError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _passwordError,
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      return FilledButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign In'),
                      );
                    },
                  ),
                  if (context.watch<AuthBloc>().state case AuthFailure failure)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          failure.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionStartupView extends StatelessWidget {
  const _SessionStartupView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Checking your secure session',
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_golf,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparing your golf experience',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking your secure session…',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewShell extends StatefulWidget {
  const _PreviewShell();

  @override
  State<_PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<_PreviewShell> {
  int _index = 0;

  static const _pages = [
    _PlayPage(),
    _CoursesPage(),
    _RoundPage(),
    _ScorePage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B1711),
      ),
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: const Color(0xFF0B1711),
          indicatorColor: const Color(0xFF24563B),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.golf_course), label: 'Chơi'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Sân'),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Vòng đấu',
            ),
            NavigationDestination(
              icon: Icon(Icons.scoreboard_outlined),
              label: 'Điểm',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3CDB7F),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.sports_golf,
                      color: Color(0xFF07100C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'VIETNAM SMART GOLF',
                          style: TextStyle(
                            color: Color(0xFF7E978A),
                            fontSize: 10,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}

class _PlayPage extends StatelessWidget {
  const _PlayPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Xin chào, Golfer',
      action: const CircleAvatar(
        backgroundColor: Color(0xFF21362B),
        child: Icon(Icons.notifications_none),
      ),
      children: [
        const SizedBox(height: 12),
        Container(
          height: 232,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF16452B), Color(0xFF0C2518)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Chip(
                label: Text('SẴN SÀNG CHƠI'),
                avatar: Icon(Icons.circle, size: 10, color: Color(0xFF3CDB7F)),
              ),
              const Spacer(),
              Text(
                'Bắt đầu vòng đấu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'GPS chính xác, ghi điểm nhanh và hỗ trợ chiến thuật theo thời gian thực.',
                style: TextStyle(color: Color(0xFFB9C9C0)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
                label: const Text('CHỌN SÂN GOLF'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Truy cập nhanh'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _QuickCard(Icons.explore_outlined, 'Tìm sân', '120+ sân'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                Icons.analytics_outlined,
                'Hiệu suất',
                'Xem thống kê',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Vòng đấu gần đây'),
        const SizedBox(height: 12),
        const _RoundTile(
          course: 'BRG Kings Island',
          date: 'Hôm qua · 18 hố',
          score: '+8',
        ),
        const SizedBox(height: 10),
        const _RoundTile(
          course: 'Sky Lake Resort',
          date: '28 Thg 7 · 18 hố',
          score: '+4',
        ),
      ],
    );
  }
}

class _CoursesPage extends StatelessWidget {
  const _CoursesPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Tìm sân golf',
      children: [
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm theo tên hoặc địa điểm',
            filled: true,
            fillColor: const Color(0xFF13231B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Gần tôi')),
            Chip(label: Text('Yêu thích')),
            Chip(label: Text('Đã tải')),
            Chip(label: Text('Mới xem')),
          ],
        ),
        const SizedBox(height: 18),
        const _CourseCard(
          'BRG Kings Island Golf Resort',
          'Đồng Mô, Sơn Tây · 12 km',
          '4.8',
          true,
        ),
        const SizedBox(height: 12),
        const _CourseCard(
          'Sky Lake Resort & Golf Club',
          'Chương Mỹ, Hà Nội · 28 km',
          '4.7',
          false,
        ),
        const SizedBox(height: 12),
        const _CourseCard(
          'Long Bien Golf Course',
          'Long Biên, Hà Nội · 9 km',
          '4.6',
          true,
        ),
      ],
    );
  }
}

class _RoundPage extends StatelessWidget {
  const _RoundPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Hố 7 · Par 4',
      action: const Chip(label: Text('GPS 3m')),
      children: [
        const SizedBox(height: 10),
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF143D28), Color(0xFF386C48)],
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.route, size: 120, color: Color(0x553CDB7F)),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: _Distance('PIN', '156', 'm'),
              ),
              Positioned(
                bottom: 18,
                right: 18,
                child: FloatingActionButton.small(
                  onPressed: null,
                  child: Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _Metric('TRƯỚC GREEN', '142 m')),
            SizedBox(width: 10),
            Expanded(child: _Metric('GIỮA GREEN', '156 m')),
            SizedBox(width: 10),
            Expanded(child: _Metric('SAU GREEN', '169 m')),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.air, color: Color(0xFF66D9FF)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gió 12 km/h · Đông Bắc',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Plays like 163 m',
                        style: TextStyle(color: Color(0xFF9FB4A8)),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text('6 IRON')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScorePage extends StatelessWidget {
  const _ScorePage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Bảng điểm',
      children: [
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(child: _Metric('TỔNG ĐIỂM', '+5')),
                Expanded(child: _Metric('THRU', '7')),
                Expanded(child: _Metric('GROSS', '33')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          7,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ScoreRow(
              index + 1,
              [4, 5, 3, 4, 4, 5, 4][index],
              [4, 6, 3, 5, 4, 6, 5][index],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('NHẬP ĐIỂM HỐ 7'),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Hồ sơ golfer',
      children: [
        const SizedBox(height: 18),
        const Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: Color(0xFF24563B),
            child: Text(
              'NG',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Nguyễn Golfer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const Center(
          child: Text(
            'Handicap 12.4 · Right handed',
            style: TextStyle(color: Color(0xFF8FA398)),
          ),
        ),
        const SizedBox(height: 24),
        const _ProfileTile(
          Icons.sports_golf,
          'Túi gậy của tôi',
          '14 gậy · Đã đồng bộ',
        ),
        const _ProfileTile(Icons.straighten, 'Đơn vị khoảng cách', 'Mét'),
        const _ProfileTile(
          Icons.watch_outlined,
          'Thiết bị kết nối',
          'Galaxy Watch · Sẵn sàng',
        ),
        const _ProfileTile(
          Icons.cloud_done_outlined,
          'Dữ liệu ngoại tuyến',
          '3 sân đã tải',
        ),
        const _ProfileTile(
          Icons.settings_outlined,
          'Cài đặt',
          'Thông báo, quyền riêng tư',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3CDB7F)),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8FA398), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({
    required this.course,
    required this.date,
    required this.score,
  });
  final String course;
  final String date;
  final String score;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF24563B),
        child: Icon(Icons.flag_outlined),
      ),
      title: Text(course, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(date),
      trailing: Text(
        score,
        style: const TextStyle(
          color: Color(0xFF3CDB7F),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard(this.name, this.location, this.rating, this.downloaded);
  final String name;
  final String location;
  final String rating;
  final bool downloaded;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF24563B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.landscape, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  location,
                  style: const TextStyle(
                    color: Color(0xFF8FA398),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFFFCA58)),
                    Text(' $rating'),
                    if (downloaded)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          Icons.download_done,
                          size: 17,
                          color: Color(0xFF3CDB7F),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class _Distance extends StatelessWidget {
  const _Distance(this.label, this.value, this.unit);
  final String label;
  final String value;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xDD07100C),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8FA398), fontSize: 10),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(unit),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF82988C),
          fontSize: 9,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.hole, this.par, this.score);
  final int hole;
  final int par;
  final int score;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF20352A),
        child: Text('$hole'),
      ),
      title: Text(
        'Hố $hole',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('Par $par'),
      trailing: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: score > par
                ? const Color(0xFFFF926B)
                : const Color(0xFF3CDB7F),
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$score',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Icon(icon, color: const Color(0xFF3CDB7F)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}
