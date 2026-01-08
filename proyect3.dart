import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reemplaza con tus credenciales reales de Supabase
  await Supabase.initialize(
    url: 'https://TU_PROYECTO.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtd2lqb3VpcWtwam9oeWxzZGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc3NTk3NzQsImV4cCI6MjA4MzMzNTc3NH0.p2M5eCW9WuQHM-D4ayq9SCiJ6qwsC4AC-IkdpsRMgpY',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

/* ====================== APP ====================== */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de Tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // Persistencia de sesión: si ya hay usuario, va al Dashboard
      home: supabase.auth.currentSession == null
          ? const LoginScreen()
          : const DashboardScreen(),
    );
  }
}

/* ====================== LOGIN ====================== */

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      error("Error de autenticación: ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : login,
                child: loading ? const CircularProgressIndicator() : const Text('Iniciar Sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================== DASHBOARD ====================== */

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          const WeatherWidget(),
          const Divider(),
          Expanded(child: TaskList(key: UniqueKey())), // UniqueKey ayuda a refrescar al volver
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskForm()));
          setState(() {}); // Refrescar lista al volver
        },
      ),
    );
  }
}

/* ====================== API EXTERNA (CLIMA) ====================== */

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String weatherInfo = 'Cargando clima...';

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    try {
      // Nota: Reemplaza TU_API_KEY por una válida de OpenWeatherMap
      final res = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=Mexico&appid=TU_API_KEY&units=metric&lang=es'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          weatherInfo = '📍 ${data['name']}: ${data['main']['temp']}°C, ${data['weather'][0]['description']}';
        });
      }
    } catch (_) {
      setState(() => weatherInfo = 'Clima no disponible');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.cloud, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(weatherInfo, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

/* ====================== LISTA DE TAREAS ====================== */

class TaskList extends StatelessWidget {
  const TaskList({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos 'tareas' que es el nombre en tu SQL (Imagen 1)
    final stream = supabase.from('tareas').stream(primaryKey: ['id']).order('fecha_creacion');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final tasks = snapshot.data!;

        if (tasks.isEmpty) return const Center(child: Text("No tienes tareas pendientes."));

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (_, i) {
            final t = tasks[i];
            return ListTile(
              leading: Icon(Icons.circle, color: _getPriorityColor(t['prioridad'])),
              title: Text(t['texto_del_título'] ?? 'Sin título'), // Según tu SQL
              subtitle: Text("${t['estado']} • ${t['prioridad']}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await supabase.from('tareas').delete().eq('id', t['id']);
                },
              ),
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'alta': return Colors.red;
      case 'media': return Colors.orange;
      default: return Colors.green;
    }
  }
}

/* ====================== FORMULARIO ====================== */

class TaskForm extends StatefulWidget {
  const TaskForm({super.key});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String priority = 'media';

  Future<void> save() async {
    final user = supabase.auth.currentUser;
    if (user == null || titleCtrl.text.isEmpty) return;

    try {
      await supabase.from('tareas').insert({
        'user_id': user.id,
        'texto_del_título': titleCtrl.text, // Match con SQL
        'texto_de_descripción': descCtrl.text, // Match con SQL
        'prioridad': priority,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Tarea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título de la tarea')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: priority,
              isExpanded: true,
              items: ['baja', 'media', 'alta'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text("Prioridad $value"));
              }).toList(),
              onChanged: (val) => setState(() => priority = val!),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: save, 
              child: const Text('Guardar Tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
